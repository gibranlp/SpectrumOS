//! The background service.
//!
//! `magnet daemon` owns the torrent session, so downloads keep going after
//! the TUI closes. The TUI and `magnet get` are clients: they talk to it
//! over a Unix socket with one JSON object per line, and start it themselves if
//! it isn't running, so there is still nothing to set up.
//!
//! The daemon shuts itself down once no client is connected and nothing is left
//! to download (finished, paused and failed torrents don't keep it alive).
//! Whatever is unfinished resumes the next time Magnet starts.

use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::{Duration, Instant};

use anyhow::{Context, Result, bail};
use serde::{Deserialize, Serialize};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{UnixListener, UnixStream};
use tokio::sync::Mutex;

use crate::engine::{self, Engine, Row, State};

/// How long the daemon waits, idle and alone, before exiting.
const IDLE_GRACE: Duration = Duration::from_secs(10);

#[derive(Serialize, Deserialize, Debug)]
#[serde(tag = "cmd", rename_all = "snake_case")]
enum Request {
    Hello,
    Rows,
    Add {
        magnet: String,
        #[serde(default)]
        name: Option<String>,
    },
    AddFile { path: PathBuf },
    Toggle { id: usize },
    Remove { id: usize, delete_files: bool },
}

#[derive(Serialize, Deserialize, Debug, Default)]
struct Response {
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    id: Option<usize>,
    #[serde(skip_serializing_if = "Option::is_none")]
    rows: Option<Vec<Row>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    out: Option<PathBuf>,
}

/// One socket per data directory, in the runtime dir (Unix socket paths are
/// limited to ~108 bytes, so the data dir is hashed rather than used directly).
pub fn socket_path() -> PathBuf {
    let data = engine::data_dir();
    let mut h: u64 = 0xcbf29ce484222325; // FNV-1a: stable across builds
    for b in data.as_os_str().as_encoded_bytes() {
        h ^= *b as u64;
        h = h.wrapping_mul(0x100000001b3);
    }
    let dir = dirs::runtime_dir().unwrap_or_else(std::env::temp_dir);
    dir.join(format!("magnet-{:08x}.sock", h as u32))
}

fn is_active(r: &Row) -> bool {
    matches!(r.state, State::Starting | State::Downloading)
}

// --- server -------------------------------------------------------------------

/// How long a magnet may look for peers before it's reported as failed. Without
/// a limit, a dead torrent would keep the service running forever.
const RESOLVE_TIMEOUT: Duration = Duration::from_secs(15 * 60);

/// Ids for magnets still being resolved, kept clear of librqbit's own ids.
const PENDING_BASE: usize = 1 << 40;

/// A magnet whose metadata is still being fetched from peers. librqbit only
/// returns from `add` once it has the metadata, which can take minutes, so the
/// request is answered right away and the add carries on in the background.
struct Pending {
    id: usize,
    name: String,
    info_hash: String,
    magnet: String,
    error: Option<String>,
    task: Option<tokio::task::AbortHandle>,
}

impl Pending {
    fn row(&self, out: &Path) -> Row {
        Row {
            id: self.id,
            info_hash: self.info_hash.clone(),
            name: self.name.clone(),
            state: if self.error.is_some() { State::Error } else { State::Starting },
            done: 0,
            total: 0,
            down: 0.0,
            up: 0.0,
            eta: None,
            peers: 0,
            uploaded: 0,
            folder: out.to_path_buf(),
            error: self.error.clone(),
        }
    }
}

#[derive(Serialize, Deserialize)]
struct SavedPending {
    magnet: String,
    name: String,
}

struct Daemon {
    engine: Arc<Engine>,
    pending: std::sync::Mutex<Vec<Pending>>,
    next_id: AtomicUsize,
}

impl Daemon {
    fn rows(&self) -> Vec<Row> {
        let mut rows = self.engine.rows();
        let pending = self.pending.lock().unwrap();
        rows.extend(pending.iter().map(|p| p.row(&self.engine.out)));
        rows
    }

    fn pending_file() -> PathBuf {
        engine::data_dir().join("pending.json")
    }

    /// Keep unresolved magnets on disk, so a restart picks them back up.
    fn save_pending(&self) {
        let saved: Vec<SavedPending> = self
            .pending
            .lock()
            .unwrap()
            .iter()
            .filter(|p| p.error.is_none())
            .map(|p| SavedPending { magnet: p.magnet.clone(), name: p.name.clone() })
            .collect();
        if let Ok(json) = serde_json::to_vec(&saved) {
            let _ = std::fs::write(Self::pending_file(), json);
        }
    }

    fn add_magnet(self: &Arc<Self>, magnet: String, name: Option<String>) -> Result<usize> {
        let parsed = crate::magnet::parse_input(&magnet).context("not a magnet link or info hash")?;
        let already = self.engine.rows().into_iter().find(|r| r.info_hash == parsed.info_hash);
        if let Some(r) = already {
            return Ok(r.id);
        }
        let id = {
            let mut pending = self.pending.lock().unwrap();
            if let Some(p) = pending.iter_mut().find(|p| p.info_hash == parsed.info_hash) {
                if p.error.is_none() {
                    return Ok(p.id); // already looking for peers
                }
                // A failed attempt: forget it and try again.
                let old = p.id;
                pending.retain(|p| p.id != old);
            }
            let id = PENDING_BASE + self.next_id.fetch_add(1, Ordering::SeqCst);
            pending.push(Pending {
                id,
                name: name.filter(|n| !n.is_empty()).unwrap_or(parsed.name),
                info_hash: parsed.info_hash,
                magnet: parsed.magnet.clone(),
                error: None,
                task: None,
            });
            id
        };
        let me = self.clone();
        let task = tokio::spawn(async move {
            let res = tokio::time::timeout(RESOLVE_TIMEOUT, me.engine.add(&parsed.magnet)).await;
            let mut pending = me.pending.lock().unwrap();
            match res {
                Ok(Ok(_)) => pending.retain(|p| p.id != id),
                Ok(Err(e)) => {
                    if let Some(p) = pending.iter_mut().find(|p| p.id == id) {
                        p.error = Some(format!("{e:#}"));
                    }
                }
                Err(_) => {
                    if let Some(p) = pending.iter_mut().find(|p| p.id == id) {
                        p.error = Some("no peers found — download it again from the results to retry".into());
                    }
                }
            }
            drop(pending);
            me.save_pending();
        });
        if let Some(p) = self.pending.lock().unwrap().iter_mut().find(|p| p.id == id) {
            p.task = Some(task.abort_handle());
        }
        self.save_pending();
        Ok(id)
    }

    /// Cancel a magnet that is still looking for peers. False if `id` isn't one.
    fn cancel_pending(&self, id: usize) -> bool {
        let removed = {
            let mut pending = self.pending.lock().unwrap();
            let before = pending.len();
            pending.retain(|p| {
                if p.id == id {
                    if let Some(t) = &p.task {
                        t.abort();
                    }
                    false
                } else {
                    true
                }
            });
            pending.len() != before
        };
        if removed {
            self.save_pending();
        }
        removed
    }
}

pub async fn serve() -> Result<()> {
    engine::migrate_old_data();
    let sock = socket_path();
    if UnixStream::connect(&sock).await.is_ok() {
        // Someone else already serves this data dir.
        return Ok(());
    }
    let _ = std::fs::remove_file(&sock);
    let listener = UnixListener::bind(&sock).with_context(|| format!("binding {}", sock.display()))?;
    // Bound before the (slower) engine start, so clients can connect and wait.
    let engine = Arc::new(Engine::start().await?);
    let daemon = Arc::new(Daemon { engine, pending: Default::default(), next_id: AtomicUsize::new(0) });
    let clients = Arc::new(AtomicUsize::new(0));
    log(&format!("started, saving to {}", daemon.engine.out.display()));

    // Magnets that were still looking for peers when the service last stopped.
    if let Ok(raw) = std::fs::read(Daemon::pending_file()) {
        for p in serde_json::from_slice::<Vec<SavedPending>>(&raw).unwrap_or_default() {
            let _ = daemon.add_magnet(p.magnet, Some(p.name));
        }
    }

    let mut check = tokio::time::interval(Duration::from_secs(1));
    let mut idle_since: Option<Instant> = None;
    let mut hangup = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::hangup())?;
    let mut term = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())?;
    loop {
        tokio::select! {
            accepted = listener.accept() => {
                if let Ok((stream, _)) = accepted {
                    let daemon = daemon.clone();
                    let clients = clients.clone();
                    clients.fetch_add(1, Ordering::SeqCst);
                    tokio::spawn(async move {
                        let _ = handle(stream, &daemon).await;
                        clients.fetch_sub(1, Ordering::SeqCst);
                    });
                }
            }
            _ = check.tick() => {
                let idle = clients.load(Ordering::SeqCst) == 0 && !daemon.rows().iter().any(is_active);
                match (idle, idle_since) {
                    (false, _) => idle_since = None,
                    (true, None) => idle_since = Some(Instant::now()),
                    (true, Some(t)) if t.elapsed() >= IDLE_GRACE => {
                        log("all downloads finished and no one is watching; stopping");
                        break;
                    }
                    _ => {}
                }
            }
            _ = hangup.recv() => {} // a closing terminal must not stop downloads
            _ = term.recv() => { log("terminated"); break; }
        }
    }
    let _ = std::fs::remove_file(&sock);
    daemon.engine.stop();
    tokio::time::sleep(Duration::from_millis(500)).await;
    Ok(())
}

async fn handle(stream: UnixStream, daemon: &Arc<Daemon>) -> Result<()> {
    let (r, mut w) = stream.into_split();
    let mut lines = BufReader::new(r).lines();
    while let Some(line) = lines.next_line().await? {
        let resp = match serde_json::from_str::<Request>(&line) {
            Err(e) => Response { error: Some(format!("bad request: {e}")), ..Default::default() },
            Ok(req) => match dispatch(req, daemon).await {
                Ok(r) => r,
                Err(e) => Response { error: Some(format!("{e:#}")), ..Default::default() },
            },
        };
        let mut out = serde_json::to_vec(&resp)?;
        out.push(b'\n');
        w.write_all(&out).await?;
    }
    Ok(())
}

async fn dispatch(req: Request, d: &Arc<Daemon>) -> Result<Response> {
    let engine = &d.engine;
    Ok(match req {
        Request::Hello => Response { out: Some(engine.out.clone()), ..Default::default() },
        Request::Rows => Response { rows: Some(d.rows()), ..Default::default() },
        Request::Add { magnet, name } => Response { id: Some(d.add_magnet(magnet, name)?), ..Default::default() },
        Request::AddFile { path } => {
            Response { id: Some(engine.add_file(&path.to_string_lossy()).await?), ..Default::default() }
        }
        Request::Toggle { id } if id >= PENDING_BASE => bail!("still finding peers — it can be paused once it starts"),
        Request::Toggle { id } => {
            engine.toggle(id).await?;
            Response::default()
        }
        Request::Remove { id, .. } if id >= PENDING_BASE => {
            d.cancel_pending(id);
            Response::default()
        }
        Request::Remove { id, delete_files } => {
            engine.remove(id, delete_files).await?;
            Response::default()
        }
    })
}

fn log(msg: &str) {
    eprintln!("[{}] {msg}", chrono_ish());
}

fn chrono_ish() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

// --- client -------------------------------------------------------------------

type Conn = (BufReader<tokio::net::unix::OwnedReadHalf>, tokio::net::unix::OwnedWriteHalf);

/// A connection to the background service. Holding it open keeps the service
/// alive; dropping it lets the service exit once downloads are done.
pub struct Client {
    conn: Mutex<Conn>,
    pub out: PathBuf,
}

impl Client {
    /// Connect to the running service, starting it first if needed.
    pub async fn connect() -> Result<Client> {
        let c = Client { conn: Mutex::new(open().await?), out: PathBuf::new() };
        let out = c.call(Request::Hello).await?.out.unwrap_or_else(engine::download_dir);
        Ok(Client { out, ..c })
    }

    async fn call(&self, req: Request) -> Result<Response> {
        let mut line = serde_json::to_vec(&req)?;
        line.push(b'\n');
        let mut conn = self.conn.lock().await;
        let raw = match exchange(&mut conn, &line).await {
            Ok(raw) => raw,
            // The service died or was restarted: reconnect (restarting it) once.
            Err(_) => {
                *conn = open().await?;
                exchange(&mut conn, &line).await?
            }
        };
        let resp: Response = serde_json::from_str(&raw)?;
        if let Some(e) = resp.error {
            bail!(e);
        }
        Ok(resp)
    }

    pub async fn rows(&self) -> Result<Vec<Row>> {
        Ok(self.call(Request::Rows).await?.rows.unwrap_or_default())
    }

    /// Queue a magnet. Returns at once; the service finds peers in the background.
    pub async fn add(&self, magnet: &str, name: Option<&str>) -> Result<usize> {
        let req = Request::Add { magnet: magnet.into(), name: name.map(String::from) };
        self.call(req).await?.id.context("no id")
    }

    pub async fn add_file(&self, path: &str) -> Result<usize> {
        let path = std::fs::canonicalize(path).with_context(|| format!("reading {path}"))?;
        self.call(Request::AddFile { path }).await?.id.context("no id")
    }

    pub async fn toggle(&self, id: usize) -> Result<()> {
        self.call(Request::Toggle { id }).await.map(|_| ())
    }

    pub async fn remove(&self, id: usize, delete_files: bool) -> Result<()> {
        self.call(Request::Remove { id, delete_files }).await.map(|_| ())
    }
}

async fn open() -> Result<Conn> {
    let sock = socket_path();
    let stream = match UnixStream::connect(&sock).await {
        Ok(s) => s,
        Err(_) => {
            spawn_daemon()?;
            wait_for(&sock).await?
        }
    };
    let (r, w) = stream.into_split();
    Ok((BufReader::new(r), w))
}

async fn exchange(conn: &mut Conn, line: &[u8]) -> Result<String> {
    conn.1.write_all(line).await?;
    let mut buf = String::new();
    if conn.0.read_line(&mut buf).await? == 0 {
        bail!("background service went away");
    }
    Ok(buf)
}

/// Start `magnet daemon` fully detached: its own session (so closing the
/// terminal or Ctrl+C doesn't reach it), no terminal I/O, log to a file.
fn spawn_daemon() -> Result<()> {
    use std::os::unix::process::CommandExt;
    let data = engine::data_dir();
    std::fs::create_dir_all(&data).ok();
    let log = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(data.join("daemon.log"))
        .context("opening daemon log")?;
    let exe = std::env::current_exe().context("finding magnet binary")?;
    let mut cmd = std::process::Command::new(exe);
    cmd.arg("daemon")
        .stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::null())
        .stderr(log);
    // SAFETY: setsid is async-signal-safe and touches no parent state.
    unsafe {
        cmd.pre_exec(|| {
            libc::setsid();
            Ok(())
        });
    }
    cmd.spawn().context("starting background service")?;
    Ok(())
}

async fn wait_for(sock: &Path) -> Result<UnixStream> {
    let deadline = Instant::now() + Duration::from_secs(15);
    loop {
        if let Ok(s) = UnixStream::connect(sock).await {
            return Ok(s);
        }
        if Instant::now() > deadline {
            bail!(
                "background service didn't start; see {}",
                engine::data_dir().join("daemon.log").display()
            );
        }
        tokio::time::sleep(Duration::from_millis(100)).await;
    }
}

pub fn active_count(rows: &[Row]) -> usize {
    rows.iter().filter(|r| is_active(r)).count()
}

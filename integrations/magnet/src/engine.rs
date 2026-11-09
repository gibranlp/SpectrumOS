//! The BitTorrent side: a librqbit session that downloads to the user's
//! downloads folder, remembers what it was doing across restarts, and keeps
//! seeding finished torrents while Magnet is open.

use std::path::PathBuf;
use std::sync::Arc;

use anyhow::{Context, Result};
use librqbit::{
    AddTorrent, AddTorrentOptions, ListenerMode, ListenerOptions, Session, SessionOptions,
    SessionPersistenceConfig, TorrentStatsState, api::TorrentIdOrHash,
};

pub fn download_dir() -> PathBuf {
    if let Some(d) = std::env::var_os("MAGNET_DOWNLOAD_DIR") {
        return PathBuf::from(d);
    }
    dirs::download_dir()
        .or_else(|| dirs::home_dir().map(|h| h.join("Downloads")))
        .unwrap_or_else(|| PathBuf::from("Downloads"))
}

/// One-time carry-over from the app's old name: copy `torrentrum`'s resume
/// state into `magnet`'s data folder so unfinished downloads still resume.
/// Copy, not move, so an old instance that's still running is undisturbed.
pub fn migrate_old_data() {
    if std::env::var_os("MAGNET_DATA_DIR").is_some() {
        return;
    }
    let Some(base) = dirs::data_dir() else { return };
    let (old, new) = (base.join("torrentrum/session"), base.join("magnet/session"));
    if new.exists() || !old.is_dir() {
        return;
    }
    if std::fs::create_dir_all(&new).is_err() {
        return;
    }
    for entry in std::fs::read_dir(&old).into_iter().flatten().flatten() {
        let _ = std::fs::copy(entry.path(), new.join(entry.file_name()));
    }
}

pub fn data_dir() -> PathBuf {
    if let Some(d) = std::env::var_os("MAGNET_DATA_DIR") {
        return PathBuf::from(d);
    }
    dirs::data_dir()
        .unwrap_or_else(std::env::temp_dir)
        .join("magnet")
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum State {
    Starting,
    Downloading,
    Seeding,
    Paused,
    Done,
    Error,
}

#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
pub struct Row {
    pub id: usize,
    pub info_hash: String,
    pub name: String,
    pub state: State,
    pub done: u64,
    pub total: u64,
    pub down: f64,
    pub up: f64,
    pub eta: Option<u64>,
    pub peers: usize,
    pub uploaded: u64,
    pub folder: PathBuf,
    pub error: Option<String>,
}

impl Row {
    pub fn fraction(&self) -> f64 {
        if self.total == 0 { 0.0 } else { self.done as f64 / self.total as f64 }
    }
}

pub struct Engine {
    session: Arc<Session>,
    pub out: PathBuf,
}

impl Engine {
    pub async fn start() -> Result<Self> {
        let out = download_dir();
        std::fs::create_dir_all(&out).with_context(|| format!("creating {}", out.display()))?;
        let state = data_dir().join("session");
        std::fs::create_dir_all(&state).ok();
        let trackers = crate::magnet::TRACKERS
            .iter()
            .filter_map(|t| t.parse().ok())
            .collect();
        let opts = SessionOptions {
            fastresume: true,
            persistence: Some(SessionPersistenceConfig::Json { folder: Some(state) }),
            listen: Some(ListenerOptions {
                mode: ListenerMode::TcpAndUtp,
                listen_addr: (std::net::Ipv6Addr::UNSPECIFIED, 0).into(),
                enable_upnp_port_forwarding: true,
                ..Default::default()
            }),
            trackers,
            client_name_and_version: Some(format!("magnet {}", env!("CARGO_PKG_VERSION"))),
            ..Default::default()
        };
        let session = Session::new_with_opts(out.clone(), opts)
            .await
            .context("starting the torrent engine")?;
        Ok(Self { session, out })
    }

    /// Queue a magnet. Returns the torrent's id.
    pub async fn add(&self, magnet: &str) -> Result<usize> {
        let resp = self
            .session
            .add_torrent(
                AddTorrent::from_url(magnet),
                Some(AddTorrentOptions {
                    // lets an interrupted download resume / a finished one seed
                    overwrite: true,
                    ..Default::default()
                }),
            )
            .await?;
        let handle = resp.into_handle().context("torrent was not added")?;
        Ok(handle.id())
    }

    /// Queue a local .torrent file.
    pub async fn add_file(&self, path: &str) -> Result<usize> {
        let bytes = tokio::fs::read(path).await.with_context(|| format!("reading {path}"))?;
        let resp = self
            .session
            .add_torrent(
                AddTorrent::from_bytes(bytes),
                Some(AddTorrentOptions { overwrite: true, ..Default::default() }),
            )
            .await?;
        Ok(resp.into_handle().context("torrent was not added")?.id())
    }

    pub fn rows(&self) -> Vec<Row> {
        let mut rows = self.session.with_torrents(|it| {
            it.map(|(id, h)| {
                let st = h.stats();
                let live = st.live.as_ref();
                let state = match st.state {
                    TorrentStatsState::Initializing { .. } => State::Starting,
                    TorrentStatsState::Paused if st.finished => State::Done,
                    TorrentStatsState::Paused => State::Paused,
                    TorrentStatsState::Error => State::Error,
                    TorrentStatsState::Live if st.finished => State::Seeding,
                    TorrentStatsState::Live => State::Downloading,
                };
                let mbps = |m: f64| m * 1024.0 * 1024.0;
                Row {
                    id,
                    info_hash: h.info_hash().as_string(),
                    name: h.name().unwrap_or_else(|| h.info_hash().as_string()),
                    state,
                    done: st.progress_bytes,
                    total: st.total_bytes,
                    down: live.map(|l| mbps(l.download_speed.mbps)).unwrap_or(0.0),
                    up: live.map(|l| mbps(l.upload_speed.mbps)).unwrap_or(0.0),
                    eta: if st.finished {
                        None
                    } else {
                        live.and_then(|l| {
                            let sp = mbps(l.download_speed.mbps);
                            (sp > 1.0).then(|| (st.total_bytes.saturating_sub(st.progress_bytes) as f64 / sp) as u64)
                        })
                    },
                    peers: live.map(|l| l.snapshot.peer_stats.live as usize).unwrap_or(0),
                    uploaded: st.uploaded_bytes,
                    folder: h.output_folder().to_path_buf(),
                    error: st.error.clone(),
                }
            })
            .collect::<Vec<_>>()
        });
        rows.sort_by_key(|r| r.id);
        rows
    }

    /// Pause a running torrent, or resume a paused one.
    pub async fn toggle(&self, id: usize) -> Result<()> {
        let h = self
            .session
            .get(TorrentIdOrHash::Id(id))
            .context("no such torrent")?;
        if h.is_paused() {
            self.session.unpause(&h).await
        } else {
            self.session.pause(&h).await
        }
    }

    /// Forget a torrent. Files on disk are kept unless `delete_files`.
    pub async fn remove(&self, id: usize, delete_files: bool) -> Result<()> {
        self.session.delete(TorrentIdOrHash::Id(id), delete_files).await
    }

    pub fn stop(&self) {
        // Persistence is flushed as torrents change state; cancelling the session
        // closes sockets cleanly.
        let s = self.session.clone();
        tokio::spawn(async move { s.stop().await });
    }
}

//! Magnet: a torrent finder that lives in your terminal.
//! Zero setup, nothing to configure; everything saves to your downloads folder.

mod app;
mod daemon;
mod engine;
mod format;
mod magnet;
mod sources;
mod theme;

use std::io::Write;
use std::sync::Arc;
use std::time::Duration;

use anyhow::{Result, bail};

use crate::sources::{Group, SourceId};

const HELP: &str = "\
Magnet — curated torrents straight from your terminal

USAGE
    magnet                    open the TUI (search, browse, download)
    magnet search <query> [--category games|movies|tv|anime|music|other]
    magnet search --top [--category movies|tv|anime|music|other]
                              print merged search results as JSON
    magnet get <magnet|hash|file.torrent>...
                              download without the TUI, then exit
    magnet daemon             the background service (started automatically)
    magnet --help | --version

Downloads save to your downloads folder (XDG_DOWNLOAD_DIR, else ~/Downloads).
Downloads keep going in a background service after you quit; it stops by
itself once everything has finished downloading.";

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let rt = tokio::runtime::Builder::new_multi_thread().enable_all().build()?;
    let code = rt.block_on(async_main(args))?;
    // Don't wait on the blocking input thread / lingering peer sockets.
    std::process::exit(code);
}

async fn async_main(args: Vec<String>) -> Result<i32> {
    match args.first().map(String::as_str) {
        None => {
            let client = Arc::new(daemon::Client::connect().await?);
            let active = app::run(client).await?;
            if active > 0 {
                println!(
                    "{active} download{} continuing in the background — the service stops itself when {} done.",
                    if active == 1 { "" } else { "s" },
                    if active == 1 { "it's" } else { "they're" },
                );
            }
            Ok(0)
        }
        Some("-h" | "--help" | "help") => {
            println!("{HELP}");
            Ok(0)
        }
        Some("-V" | "--version") => {
            println!("magnet {}", env!("CARGO_PKG_VERSION"));
            Ok(0)
        }
        Some("search") => search(&args[1..]).await,
        Some("get") => get(&args[1..]).await,
        Some("daemon") => daemon::serve().await.map(|_| 0),
        Some(other) => {
            eprintln!("unknown command: {other}\n\n{HELP}");
            Ok(2)
        }
    }
}

async fn search(args: &[String]) -> Result<i32> {
    let mut group = Group::All;
    let mut top = false;
    let mut words = Vec::new();
    let mut it = args.iter();
    while let Some(a) = it.next() {
        if a == "--category" || a == "-c" {
            let v = it.next().map(String::as_str).unwrap_or("");
            group = Group::parse(v).ok_or_else(|| anyhow::anyhow!("unknown category: {v}"))?;
        } else if let Some(v) = a.strip_prefix("--category=") {
            group = Group::parse(v).ok_or_else(|| anyhow::anyhow!("unknown category: {v}"))?;
        } else if a == "--top" {
            top = true;
        } else {
            words.push(a.clone());
        }
    }
    let query = words.join(" ");
    let http = sources::http_client();
    if top && !query.is_empty() {
        bail!("--top takes no query");
    }
    let srcs: Vec<SourceId> =
        SourceId::ALL.into_iter().filter(|s| s.in_group(group) && (!top || s.has_top())).collect();
    let results = futures::future::join_all(srcs.iter().map(|s| {
        let http = http.clone();
        let q = query.clone();
        async move {
            let job = async { if top { s.top(&http).await } else { s.search(&http, &q).await } };
            let r = tokio::time::timeout(Duration::from_secs(45), job).await;
            (*s, r.map_err(|_| anyhow::anyhow!("timed out")).and_then(|x| x))
        }
    }))
    .await;

    let mut all = Vec::new();
    let mut sources_json = Vec::new();
    for (s, r) in results {
        match r {
            Ok(list) => {
                sources_json.push(serde_json::json!({"source": s, "ok": true, "count": list.len()}));
                all.extend(list);
            }
            Err(e) => sources_json.push(serde_json::json!({"source": s, "ok": false, "error": app::short_err(&e)})),
        }
    }
    let mut merged = sources::dedupe(all);
    sources::default_order(&mut merged);
    if top {
        merged.truncate(100);
    }
    let doc = serde_json::json!({
        "query": query,
        "top": top,
        "category": group.label().to_lowercase(),
        "sources": sources_json,
        "results": merged,
    });
    // Ignore a closed pipe (e.g. `magnet search x | head`).
    let _ = writeln!(std::io::stdout(), "{}", serde_json::to_string_pretty(&doc)?);
    Ok(0)
}

async fn get(args: &[String]) -> Result<i32> {
    if args.is_empty() {
        bail!("get needs a magnet link, info hash, or .torrent file");
    }
    let client = daemon::Client::connect().await?;
    // Track by info hash: a magnet changes id once its peers are found.
    let mut hashes = Vec::new();
    for a in args {
        if let Some(p) = magnet::parse_input(a) {
            client.add(&p.magnet, None).await?;
            hashes.push(p.info_hash);
        } else if std::path::Path::new(a).is_file() {
            let id = client.add_file(a).await?;
            let row = client.rows().await?.into_iter().find(|r| r.id == id);
            hashes.extend(row.map(|r| r.info_hash));
        } else {
            bail!("not a magnet, info hash, or .torrent file: {a}");
        }
    }
    eprintln!("saving to {}", client.out.display());

    let mut tick = tokio::time::interval(Duration::from_millis(500));
    loop {
        tokio::select! {
            _ = tick.tick() => {}
            _ = tokio::signal::ctrl_c() => {
                eprintln!("\ndetached — downloads continue in the background");
                return Ok(0);
            }
        }
        let rows: Vec<engine::Row> = client.rows().await?.into_iter().filter(|r| hashes.contains(&r.info_hash)).collect();
        let line: Vec<String> = rows
            .iter()
            .map(|r| format!("{} {:.0}% ↓{}", app::ellipsize(&r.name, 30), r.fraction() * 100.0, format::speed(r.down)))
            .collect();
        eprint!("\r\x1b[2K{}", line.join("  |  "));
        let _ = std::io::stderr().flush();
        let pending = rows.iter().any(|r| matches!(r.state, engine::State::Starting | engine::State::Downloading));
        if !pending {
            eprintln!();
            let mut code = 0;
            for r in &rows {
                match r.state {
                    engine::State::Error => {
                        eprintln!("✗ {}: {}", r.name, r.error.clone().unwrap_or_default());
                        code = 1;
                    }
                    engine::State::Paused => eprintln!("⏸ {} (paused)", r.name),
                    _ => eprintln!("✓ {}", r.name),
                }
            }
            return Ok(code);
        }
    }
}

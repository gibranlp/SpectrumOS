//! The curated source list and the code that asks each of them.

use std::collections::HashMap;
use std::time::Duration;

use anyhow::{Context, Result, bail};
use serde::Serialize;
use serde_json::Value;

use crate::format::{parse_date, parse_size, unescape};
use crate::magnet::{build_magnet, merge_trackers, parse_magnet};

pub const USER_AGENT: &str = concat!(
    "magnet/",
    env!("CARGO_PKG_VERSION"),
    " (+https://github.com/gibranlp/Magnet)"
);

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize)]
#[serde(rename_all = "kebab-case")]
pub enum SourceId {
    Fitgirl,
    Yts,
    TpbMovies,
    Eztv,
    TpbTv,
    Nyaa,
    Subsplease,
    TpbMusic,
    TpbOther,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Group {
    All,
    Games,
    Movies,
    Tv,
    Anime,
    Music,
    Other,
}

impl Group {
    pub const TABS: [Group; 7] = [
        Group::All,
        Group::Games,
        Group::Movies,
        Group::Tv,
        Group::Anime,
        Group::Music,
        Group::Other,
    ];

    pub fn label(self) -> &'static str {
        match self {
            Group::All => "All",
            Group::Games => "Games",
            Group::Movies => "Movies",
            Group::Tv => "TV",
            Group::Anime => "Anime",
            Group::Music => "Music",
            Group::Other => "Other",
        }
    }

    pub fn parse(s: &str) -> Option<Group> {
        match s.to_ascii_lowercase().as_str() {
            "all" => Some(Group::All),
            "games" | "game" => Some(Group::Games),
            "movies" | "movie" => Some(Group::Movies),
            "tv" | "shows" => Some(Group::Tv),
            "anime" => Some(Group::Anime),
            "music" | "audio" => Some(Group::Music),
            "other" | "books" | "ebooks" | "comics" => Some(Group::Other),
            _ => None,
        }
    }
}

impl SourceId {
    pub const ALL: [SourceId; 9] = [
        SourceId::Fitgirl,
        SourceId::Yts,
        SourceId::TpbMovies,
        SourceId::Eztv,
        SourceId::TpbTv,
        SourceId::Nyaa,
        SourceId::Subsplease,
        SourceId::TpbMusic,
        SourceId::TpbOther,
    ];

    pub fn label(self) -> &'static str {
        match self {
            SourceId::Fitgirl => "FitGirl",
            SourceId::Yts => "YTS",
            SourceId::TpbMovies | SourceId::TpbTv | SourceId::TpbMusic | SourceId::TpbOther => "TPB",
            SourceId::Eztv => "EZTV",
            SourceId::Nyaa => "Nyaa",
            SourceId::Subsplease => "SubsPlease",
        }
    }

    pub fn tag(self) -> &'static str {
        match self {
            SourceId::Fitgirl => "FG",
            SourceId::Yts => "YTS",
            SourceId::TpbMovies | SourceId::TpbTv | SourceId::TpbMusic | SourceId::TpbOther => "TPB",
            SourceId::Eztv => "EZTV",
            SourceId::Nyaa => "NYAA",
            SourceId::Subsplease => "SUB",
        }
    }

    pub fn groups(self) -> &'static [Group] {
        match self {
            SourceId::Fitgirl => &[Group::Games],
            SourceId::Yts | SourceId::TpbMovies => &[Group::Movies],
            SourceId::Eztv | SourceId::TpbTv => &[Group::Tv],
            SourceId::Nyaa | SourceId::Subsplease => &[Group::Anime],
            SourceId::TpbMusic => &[Group::Music],
            SourceId::TpbOther => &[Group::Other],
        }
    }

    /// False when the feed has no swarm data, so 0 seeders means "unknown".
    pub fn reports_health(self) -> bool {
        !matches!(self, SourceId::Fitgirl | SourceId::Subsplease)
    }

    pub fn in_group(self, g: Group) -> bool {
        g == Group::All || self.groups().contains(&g)
    }

    /// Whether this source can rank its catalogue by seeders for the Top 100.
    /// FitGirl and SubsPlease report no swarm data; EZTV's API can't sort.
    pub fn has_top(self) -> bool {
        matches!(
            self,
            SourceId::Yts
                | SourceId::TpbMovies
                | SourceId::TpbTv
                | SourceId::TpbMusic
                | SourceId::TpbOther
                | SourceId::Nyaa
        )
    }

    /// The most-seeded torrents this source knows, adult content filtered out.
    pub async fn top(self, http: &reqwest::Client) -> Result<Vec<TorrentResult>> {
        let mut list = match self {
            SourceId::Yts => yts_list(http, "limit=50&sort_by=seeds".into()).await?,
            SourceId::TpbMovies => tpb_top(http, &TPB_MOVIES, self).await?,
            SourceId::TpbTv => tpb_top(http, &TPB_TV, self).await?,
            SourceId::TpbMusic => tpb_top(http, &TPB_MUSIC, self).await?,
            SourceId::TpbOther => tpb_top(http, &TPB_OTHER, self).await?,
            SourceId::Nyaa => nyaa_rss(http, "c=1_0&f=0&s=seeders&o=desc").await?,
            _ => vec![],
        };
        list.retain(|r| !looks_adult(&r.name));
        Ok(list)
    }

    pub async fn search(self, http: &reqwest::Client, q: &str) -> Result<Vec<TorrentResult>> {
        let q = q.trim();
        match self {
            SourceId::Fitgirl => wordpress_rss(http, "https://fitgirl-repacks.site", self, q).await,
            SourceId::Yts => yts(http, q).await,
            SourceId::TpbMovies => tpb(http, q, &TPB_MOVIES, self).await,
            SourceId::TpbTv => tpb(http, q, &TPB_TV, self).await,
            SourceId::TpbMusic => tpb(http, q, &TPB_MUSIC, self).await,
            SourceId::TpbOther => tpb(http, q, &TPB_OTHER, self).await,
            SourceId::Eztv => eztv(http, q).await,
            SourceId::Nyaa => nyaa(http, q).await,
            SourceId::Subsplease => subsplease(http, q).await,
        }
    }
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TorrentResult {
    pub info_hash: String,
    pub name: String,
    pub size_bytes: u64,
    pub seeders: u64,
    pub leechers: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub num_files: Option<u64>,
    pub source: SourceId,
    pub magnet: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub added: Option<i64>,
    /// What kind of item this is, when the source says (e.g. "E-book", "FLAC").
    #[serde(skip_serializing_if = "Option::is_none")]
    pub kind: Option<&'static str>,
}

pub fn http_client() -> reqwest::Client {
    reqwest::Client::builder()
        .user_agent(USER_AGENT)
        .timeout(Duration::from_secs(20))
        .connect_timeout(Duration::from_secs(10))
        .build()
        .expect("http client")
}

const RETRY_STATUS: [u16; 7] = [408, 425, 429, 500, 502, 503, 504];

/// GET with a small, bounded retry on transient failures.
async fn get(http: &reqwest::Client, url: &str, retries: u32) -> Result<reqwest::Response> {
    let mut attempt = 0;
    loop {
        let res = http.get(url).send().await;
        match res {
            Ok(r) if r.status().is_success() => return Ok(r),
            Ok(r) if RETRY_STATUS.contains(&r.status().as_u16()) && attempt < retries => {
                let server = r
                    .headers()
                    .get("server")
                    .and_then(|v| v.to_str().ok())
                    .unwrap_or("")
                    .to_ascii_lowercase();
                if server.contains("cloudflare") || server.contains("ddos-guard") {
                    bail!("blocked by {server} (HTTP {})", r.status().as_u16());
                }
            }
            Ok(r) => bail!("HTTP {}", r.status().as_u16()),
            Err(e) if attempt >= retries => return Err(e.into()),
            Err(_) => {}
        }
        attempt += 1;
        tokio::time::sleep(Duration::from_millis(500 * 2u64.pow(attempt))).await;
    }
}

async fn get_json(http: &reqwest::Client, url: &str, retries: u32) -> Result<Value> {
    let r = get(http, url, retries).await?;
    r.json().await.context("bad JSON")
}

async fn get_text(http: &reqwest::Client, url: &str, retries: u32) -> Result<String> {
    Ok(get(http, url, retries).await?.text().await?)
}

fn num(v: &Value) -> u64 {
    match v {
        Value::Number(n) => n.as_u64().or_else(|| n.as_f64().map(|f| f as u64)).unwrap_or(0),
        Value::String(s) => s.trim().parse().unwrap_or(0),
        _ => 0,
    }
}

fn s(v: &Value) -> &str {
    v.as_str().unwrap_or("")
}

fn result(
    info_hash: String,
    name: String,
    size: u64,
    seeders: u64,
    leechers: u64,
    source: SourceId,
    added: Option<i64>,
) -> TorrentResult {
    TorrentResult {
        magnet: build_magnet(&info_hash, &name),
        info_hash,
        name,
        size_bytes: size,
        seeders,
        leechers,
        num_files: None,
        kind: None,
        source,
        added,
    }
}

// --- YTS ------------------------------------------------------------------

async fn yts(http: &reqwest::Client, q: &str) -> Result<Vec<TorrentResult>> {
    let params = if q.is_empty() {
        "limit=50&sort_by=date_added".to_string()
    } else {
        format!("limit=50&query_term={}", urlencoding::encode(q))
    };
    yts_list(http, params).await
}

async fn yts_list(http: &reqwest::Client, params: String) -> Result<Vec<TorrentResult>> {
    let mut last = None;
    for host in ["yts.mx", "yts.am", "yts.rs"] {
        let url = format!("https://{host}/api/v2/list_movies.json?{params}");
        match get_json(http, &url, 1).await {
            Ok(json) => {
                let mut out = Vec::new();
                for movie in json["data"]["movies"].as_array().into_iter().flatten() {
                    let base = [s(&movie["title_long"]), s(&movie["title"])]
                        .into_iter()
                        .find(|x| !x.is_empty())
                        .unwrap_or("Unknown");
                    for t in movie["torrents"].as_array().into_iter().flatten() {
                        let hash = s(&t["hash"]).to_ascii_lowercase();
                        if hash.is_empty() {
                            continue;
                        }
                        let tag = [s(&t["quality"]), s(&t["type"])]
                            .into_iter()
                            .filter(|x| !x.is_empty())
                            .collect::<Vec<_>>()
                            .join(" ");
                        let name = if tag.is_empty() {
                            base.to_string()
                        } else {
                            format!("{base} [{tag}]")
                        };
                        out.push(result(
                            hash,
                            name,
                            num(&t["size_bytes"]),
                            num(&t["seeds"]),
                            num(&t["peers"]),
                            SourceId::Yts,
                            movie["date_uploaded_unix"].as_i64(),
                        ));
                    }
                }
                return Ok(out);
            }
            Err(e) => last = Some(e),
        }
    }
    Err(last.unwrap_or_else(|| anyhow::anyhow!("YTS unreachable")))
}

// --- The Pirate Bay (apibay) ----------------------------------------------
//
// One TPB source per category tab. Each searches a top-level apibay category
// server-side (video 200, audio 100, other 600) and keeps the subcategories it
// owns. Movies and TV both search video, so identical requests are shared.

struct TpbCat {
    /// apibay top-level category to search.
    parent: u32,
    /// Subcategories kept, with the label shown for each.
    keep: &'static [(u64, &'static str)],
    /// Precompiled top-100 list used for browsing (empty query).
    top: u32,
}

const TPB_MOVIES: TpbCat = TpbCat {
    parent: 200,
    keep: &[(201, "Movie"), (202, "Movie DVD"), (207, "HD Movie"), (209, "3D Movie"), (211, "UHD Movie")],
    top: 207,
};
const TPB_TV: TpbCat = TpbCat { parent: 200, keep: &[(205, "TV"), (208, "HD TV"), (212, "UHD TV")], top: 208 };
const TPB_MUSIC: TpbCat = TpbCat { parent: 100, keep: &[(101, "Music"), (104, "FLAC")], top: 100 };
const TPB_OTHER: TpbCat = TpbCat {
    parent: 600,
    keep: &[(601, "E-book"), (602, "Comic"), (603, "Picture"), (604, "Cover"), (699, "Other")],
    top: 600,
};

type Shared = std::sync::Arc<tokio::sync::OnceCell<Result<Value, String>>>;
static TPB_CACHE: std::sync::Mutex<Vec<(String, std::time::Instant, Shared)>> = std::sync::Mutex::new(Vec::new());

/// GET apibay JSON, sharing one in-flight/recent request per URL.
async fn tpb_json(http: &reqwest::Client, url: String) -> Result<Value> {
    let cell = {
        let mut cache = TPB_CACHE.lock().unwrap();
        cache.retain(|(_, at, _)| at.elapsed() < Duration::from_secs(60));
        match cache.iter().find(|(u, _, _)| *u == url) {
            Some((_, _, c)) => c.clone(),
            None => {
                let c: Shared = Default::default();
                cache.push((url.clone(), std::time::Instant::now(), c.clone()));
                c
            }
        }
    };
    let r = cell
        .get_or_init(|| async { get_json(http, &url, 1).await.map_err(|e| format!("{e:#}")) })
        .await;
    r.clone().map_err(|e| anyhow::anyhow!(e))
}

async fn tpb(http: &reqwest::Client, q: &str, cat: &TpbCat, source: SourceId) -> Result<Vec<TorrentResult>> {
    const API: &str = "https://apibay.org";
    let items = if q.is_empty() {
        tpb_json(http, format!("{API}/precompiled/data_top100_{}.json", cat.top)).await?
    } else {
        let enc = urlencoding::encode(q);
        let first = tpb_json(http, format!("{API}/q.php?q={enc}&cat={}", cat.parent)).await?;
        let sentinel = first.as_array().is_some_and(|a| a.len() == 1 && s(&a[0]["id"]) == "0");
        if sentinel {
            // apibay caches per URL and can be stuck on a bogus "no results";
            // the same query in another parameter order re-rolls that cache key.
            tpb_json(http, format!("{API}/q.php?cat={}&q={enc}", cat.parent)).await?
        } else {
            first
        }
    };
    Ok(tpb_rows(&items, cat, source))
}

/// The per-subcategory top-100 lists this tab owns, merged.
async fn tpb_top(http: &reqwest::Client, cat: &TpbCat, source: SourceId) -> Result<Vec<TorrentResult>> {
    let lists = futures::future::join_all(cat.keep.iter().map(|(c, _)| {
        tpb_json(http, format!("https://apibay.org/precompiled/data_top100_{c}.json"))
    }))
    .await;
    let mut out = Vec::new();
    let mut last = None;
    for l in lists {
        match l {
            Ok(items) => out.extend(tpb_rows(&items, cat, source)),
            Err(e) => last = Some(e),
        }
    }
    match last {
        Some(e) if out.is_empty() => Err(e),
        _ => Ok(out),
    }
}

/// apibay rows -> results, keeping only the subcategories this tab owns
/// (which also keeps the 500s, porn, out).
fn tpb_rows(items: &Value, cat: &TpbCat, source: SourceId) -> Vec<TorrentResult> {
    let mut out = Vec::new();
    for it in items.as_array().into_iter().flatten() {
        let Some((_, kind)) = cat.keep.iter().find(|(c, _)| *c == num(&it["category"])) else {
            continue;
        };
        let hash = s(&it["info_hash"]).to_ascii_lowercase();
        if hash.is_empty() || hash.bytes().all(|b| b == b'0') || s(&it["id"]) == "0" {
            continue;
        }
        let mut r = result(
            hash,
            s(&it["name"]).to_string(),
            num(&it["size"]),
            num(&it["seeders"]),
            num(&it["leechers"]),
            source,
            Some(num(&it["added"]) as i64).filter(|x| *x > 0),
        );
        r.num_files = Some(num(&it["num_files"])).filter(|n| *n > 0);
        r.kind = Some(kind);
        out.push(r);
    }
    out
}

/// Names that give away adult content, for the unasked-for Top 100 lists.
fn looks_adult(name: &str) -> bool {
    const WORDS: [&str; 10] =
        ["xxx", "porn", "erotic", "hentai", "nsfw", "onlyfans", "sex", "nude", "playboy", "18+"];
    let n = name.to_lowercase();
    n.split(|c: char| !c.is_alphanumeric() && c != '+')
        .any(|w| WORDS.iter().any(|x| w == *x || (x.len() > 3 && w.starts_with(x))))
}

// --- EZTV -----------------------------------------------------------------
//
// EZTV's API takes no text query, only imdb_id. Match the query against the
// recent feed, then pull the full catalogue of the shows that matched.

async fn eztv_page(http: &reqwest::Client, extra: &str, retries: u32) -> Result<Vec<Value>> {
    let url = format!("https://eztvx.to/api/get-torrents?limit=100&{extra}");
    let json = get_json(http, &url, retries).await?;
    Ok(json["torrents"].as_array().cloned().unwrap_or_default())
}

static EZTV_INDEX: tokio::sync::Mutex<Option<(std::time::Instant, Vec<Value>)>> =
    tokio::sync::Mutex::const_new(None);

async fn eztv_index(http: &reqwest::Client) -> Result<Vec<Value>> {
    let mut guard = EZTV_INDEX.lock().await;
    if let Some((at, rows)) = guard.as_ref() {
        if at.elapsed() < Duration::from_secs(300) {
            return Ok(rows.clone());
        }
    }
    let first = eztv_page(http, "page=1", 1).await?;
    let rest = futures::future::join_all(
        (2..=10).map(|p| async move { eztv_page(http, &format!("page={p}"), 0).await.unwrap_or_default() }),
    )
    .await;
    let rows: Vec<Value> = first.into_iter().chain(rest.into_iter().flatten()).collect();
    *guard = Some((std::time::Instant::now(), rows.clone()));
    Ok(rows)
}

fn eztv_results(rows: &[Value]) -> Vec<TorrentResult> {
    let mut seen = std::collections::HashSet::new();
    let mut out = Vec::new();
    for t in rows {
        let hash = s(&t["hash"]).to_ascii_lowercase();
        if hash.is_empty() || !seen.insert(hash.clone()) {
            continue;
        }
        let name = [s(&t["title"]), s(&t["filename"])]
            .into_iter()
            .find(|x| !x.is_empty())
            .unwrap_or(&hash)
            .to_string();
        let mut r = result(
            hash,
            name,
            num(&t["size_bytes"]),
            num(&t["seeds"]),
            num(&t["peers"]),
            SourceId::Eztv,
            t["date_released_unix"].as_i64(),
        );
        let m = s(&t["magnet_url"]);
        if !m.is_empty() {
            r.magnet = m.to_string();
        }
        out.push(r);
    }
    out
}

async fn eztv(http: &reqwest::Client, q: &str) -> Result<Vec<TorrentResult>> {
    if q.is_empty() {
        return Ok(eztv_results(&eztv_page(http, "page=1", 1).await?));
    }
    let tokens: Vec<String> = q.to_lowercase().split_whitespace().map(String::from).collect();
    let matches = |t: &Value| {
        let hay = format!("{} {}", s(&t["title"]), s(&t["filename"])).to_lowercase();
        tokens.iter().all(|tok| hay.contains(tok))
    };
    let recent = eztv_index(http).await?;
    let hits: Vec<Value> = recent.into_iter().filter(|t| matches(t)).collect();
    let mut ids: Vec<String> = Vec::new();
    for t in &hits {
        let id = match &t["imdb_id"] {
            Value::String(s) => s.trim().to_string(),
            Value::Number(n) => n.to_string(),
            _ => String::new(),
        };
        if !id.is_empty() && id != "0" && !ids.contains(&id) {
            ids.push(id);
            if ids.len() == 2 {
                break;
            }
        }
    }
    let catalogues = futures::future::join_all(ids.iter().map(|id| async move {
        eztv_page(http, &format!("page=1&imdb_id={id}"), 0).await.unwrap_or_default()
    }))
    .await;
    let mut rows = hits;
    rows.extend(catalogues.into_iter().flatten().filter(|t| matches(t)));
    let mut out = eztv_results(&rows);
    out.sort_by(|a, b| b.seeders.cmp(&a.seeders));
    out.truncate(100);
    Ok(out)
}

// --- RSS helpers ------------------------------------------------------------

fn xml_tag<'a>(item: &'a str, name: &str) -> &'a str {
    let open = format!("<{name}>");
    let close = format!("</{name}>");
    let Some(start) = item.find(&open).map(|i| i + open.len()) else {
        return "";
    };
    let Some(len) = item[start..].find(&close) else {
        return "";
    };
    let v = item[start..start + len].trim();
    v.strip_prefix("<![CDATA[")
        .and_then(|v| v.strip_suffix("]]>"))
        .unwrap_or(v)
        .trim()
}

// --- Nyaa -----------------------------------------------------------------

async fn nyaa(http: &reqwest::Client, q: &str) -> Result<Vec<TorrentResult>> {
    nyaa_rss(http, &format!("q={}&c=0_0&f=0", urlencoding::encode(q))).await
}

async fn nyaa_rss(http: &reqwest::Client, params: &str) -> Result<Vec<TorrentResult>> {
    let url = format!("https://nyaa.si/?page=rss&{params}");
    let xml = get_text(http, &url, 2).await?;
    let mut out = Vec::new();
    for item in xml.split("<item>").skip(1) {
        let hash = xml_tag(item, "nyaa:infoHash").to_ascii_lowercase();
        let name = unescape(xml_tag(item, "title"));
        if hash.is_empty() || name.is_empty() {
            continue;
        }
        out.push(result(
            hash,
            name,
            parse_size(xml_tag(item, "nyaa:size")),
            xml_tag(item, "nyaa:seeders").parse().unwrap_or(0),
            xml_tag(item, "nyaa:leechers").parse().unwrap_or(0),
            SourceId::Nyaa,
            parse_date(xml_tag(item, "pubDate")),
        ));
    }
    Ok(out)
}

// --- SubsPlease -------------------------------------------------------------

async fn subsplease(http: &reqwest::Client, q: &str) -> Result<Vec<TorrentResult>> {
    let url = if q.is_empty() {
        "https://subsplease.org/api/?tz=UTC&f=latest".to_string()
    } else {
        format!("https://subsplease.org/api/?tz=UTC&f=search&s={}", urlencoding::encode(q))
    };
    let json = get_json(http, &url, 2).await?;
    let Some(map) = json.as_object() else {
        return Ok(vec![]);
    };
    let mut out = Vec::new();
    for entry in map.values() {
        let downloads = entry["downloads"].as_array().cloned().unwrap_or_default();
        let has = |d: &&Value| !s(&d["magnet"]).is_empty();
        let best = ["1080", "720", "480"]
            .iter()
            .find_map(|res| downloads.iter().filter(has).find(|d| s(&d["res"]) == *res))
            .or_else(|| downloads.iter().find(has));
        let Some(dl) = best else { continue };
        let m = s(&dl["magnet"]);
        let Some(parsed) = parse_magnet(m) else { continue };
        let ep = s(&entry["episode"]);
        let res = s(&dl["res"]);
        let name = format!(
            "{}{} [{}p]",
            [s(&entry["show"])].into_iter().find(|x| !x.is_empty()).unwrap_or("Unknown"),
            if ep.is_empty() { String::new() } else { format!(" - {ep}") },
            if res.is_empty() { "?" } else { res },
        );
        let size = m
            .split(['?', '&'])
            .find_map(|kv| kv.strip_prefix("xl="))
            .and_then(|v| v.parse().ok())
            .unwrap_or(0);
        out.push(TorrentResult {
            info_hash: parsed.info_hash,
            name,
            size_bytes: size,
            seeders: 0,
            leechers: 0,
            num_files: None,
            kind: None,
            source: SourceId::Subsplease,
            magnet: parsed.magnet,
            added: parse_date(s(&entry["release_date"])),
        });
    }
    Ok(out)
}

// --- WordPress RSS (FitGirl) -------------------------------------------------

fn parse_rss(xml: &str, source: SourceId) -> Vec<TorrentResult> {
    let mut out = Vec::new();
    for item in xml.split("<item>").skip(1) {
        let Some(start) = item.find("href=\"magnet:?") else { continue };
        let rest = &item[start + 6..];
        let Some(end) = rest.find('"') else { continue };
        let magnet = unescape(&rest[..end]);
        let Some(p) = parse_magnet(&magnet) else { continue };
        out.push(TorrentResult {
            info_hash: p.info_hash,
            name: unescape(xml_tag(item, "title")),
            size_bytes: 0,
            seeders: 0,
            leechers: 0,
            num_files: None,
            kind: None,
            source,
            magnet,
            added: parse_date(xml_tag(item, "pubDate")),
        });
    }
    out
}

async fn wordpress_rss(
    http: &reqwest::Client,
    base: &str,
    source: SourceId,
    q: &str,
) -> Result<Vec<TorrentResult>> {
    let feed = |page: u32| {
        let url = if q.is_empty() {
            format!("{base}/feed/")
        } else {
            format!("{base}/?s={}&feed=rss2&orderby=relevance", urlencoding::encode(q))
        };
        if page <= 1 {
            url
        } else {
            format!("{url}{}paged={page}", if q.is_empty() { "?" } else { "&" })
        }
    };
    let first = get_text(http, &feed(1), 2).await?;
    let mut out = parse_rss(&first, source);
    if first.matches("<item>").count() < 10 {
        return Ok(out);
    }
    let deeper = futures::future::join_all((2..=3).map(|p| {
        let url = feed(p);
        async move { get_text(http, &url, 2).await.map(|x| parse_rss(&x, source)).unwrap_or_default() }
    }))
    .await;
    for r in deeper.into_iter().flatten() {
        if !out.iter().any(|o| o.info_hash == r.info_hash) {
            out.push(r);
        }
    }
    Ok(out)
}

// --- merging ------------------------------------------------------------------

/// Same torrent from several sources -> one row. The healthiest row wins, but
/// absorbs the others' trackers and any fields it never reported.
pub fn dedupe(list: Vec<TorrentResult>) -> Vec<TorrentResult> {
    let mut order: Vec<String> = Vec::new();
    let mut by: HashMap<String, TorrentResult> = HashMap::new();
    for r in list {
        match by.remove(&r.info_hash) {
            None => {
                order.push(r.info_hash.clone());
                by.insert(r.info_hash.clone(), r);
            }
            Some(e) => {
                let (win, lost) = if r.seeders > e.seeders { (r, e) } else { (e, r) };
                let merged = TorrentResult {
                    magnet: merge_trackers(&win.magnet, &lost.magnet),
                    num_files: win.num_files.or(lost.num_files),
                    added: win.added.or(lost.added),
                    kind: win.kind.or(lost.kind),
                    ..win
                };
                by.insert(merged.info_hash.clone(), merged);
            }
        }
    }
    order.into_iter().filter_map(|h| by.remove(&h)).collect()
}

/// Healthiest first, newest breaks ties.
pub fn default_order(list: &mut [TorrentResult]) {
    list.sort_by(|a, b| b.seeders.cmp(&a.seeders).then(b.added.unwrap_or(0).cmp(&a.added.unwrap_or(0))));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dedupe_merges() {
        let a = result("aa".into(), "x".into(), 0, 5, 0, SourceId::Yts, None);
        let mut b = result("aa".into(), "x".into(), 10, 9, 0, SourceId::TpbMovies, Some(3));
        b.magnet.push_str("&tr=udp%3A%2F%2Fextra");
        let mut a2 = a.clone();
        a2.magnet.push_str("&tr=udp%3A%2F%2Fonly-a");
        let out = dedupe(vec![a2, b]);
        assert_eq!(out.len(), 1);
        assert_eq!(out[0].source, SourceId::TpbMovies);
        assert!(out[0].magnet.contains("only-a"));
        assert_eq!(out[0].added, Some(3));
    }

    #[test]
    fn adult_filter() {
        assert!(looks_adult("Some.XXX.Release.1080p"));
        assert!(looks_adult("E-book Erotic Collection"));
        assert!(looks_adult("Pornstar thing"));
        assert!(!looks_adult("Sussex Gardens S01"));
        assert!(!looks_adult("The Complete Calvin and Hobbes"));
        assert!(!looks_adult("Essex County 2023 1080p"));
    }

    #[test]
    fn rss_parse() {
        let xml = r#"<rss><item><title>Game &#8211; v1</title><pubDate>Thu, 01 Jan 1970 00:00:00 +0000</pubDate>
            <a href="magnet:?xt=urn:btih:abcdef0123456789abcdef0123456789abcdef01&#038;dn=g">m</a></item></rss>"#;
        let r = parse_rss(xml, SourceId::Fitgirl);
        assert_eq!(r.len(), 1);
        assert_eq!(r[0].name, "Game - v1");
        assert!(r[0].magnet.contains("&dn=g"));
    }
}

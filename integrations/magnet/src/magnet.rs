//! Magnet links and info hashes: building, parsing, merging tracker lists.

pub const TRACKERS: &[&str] = &[
    "udp://tracker.opentrackr.org:1337/announce",
    "udp://open.demonii.com:1337/announce",
    "udp://tracker.openbittorrent.com:6969/announce",
    "udp://tracker.torrent.eu.org:451/announce",
    "udp://exodus.desync.com:6969/announce",
    "udp://open.stealth.si:80/announce",
    "udp://tracker.dler.org:6969/announce",
    // HTTP(S) endpoints so peer discovery still works where UDP is blocked.
    "http://tracker.opentrackr.org:1337/announce",
    "http://tracker.openbittorrent.com:80/announce",
    "http://tracker.dler.org:6969/announce",
    "https://tracker.tamersunion.org:443/announce",
];

pub fn build_magnet(info_hash: &str, name: &str) -> String {
    let mut s = format!(
        "magnet:?xt=urn:btih:{}&dn={}",
        info_hash,
        urlencoding::encode(name)
    );
    for t in TRACKERS {
        s.push_str("&tr=");
        s.push_str(&urlencoding::encode(t));
    }
    s
}

const BASE32: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

fn base32_to_hex(b32: &str) -> Option<String> {
    let mut bits = 0u32;
    let mut value = 0u32;
    let mut out = String::new();
    for c in b32.to_ascii_uppercase().bytes() {
        let idx = BASE32.iter().position(|&b| b == c)? as u32;
        value = (value << 5) | idx;
        bits += 5;
        if bits >= 8 {
            bits -= 8;
            out.push_str(&format!("{:02x}", (value >> bits) & 0xff));
            value &= (1 << bits) - 1;
        }
    }
    (out.len() == 40).then_some(out)
}

pub fn normalize_info_hash(raw: &str) -> String {
    if raw.len() == 32 {
        base32_to_hex(raw).unwrap_or_else(|| raw.to_ascii_lowercase())
    } else {
        raw.to_ascii_lowercase()
    }
}

pub fn is_info_hash(s: &str) -> bool {
    let s = s.trim();
    (s.len() == 40 && s.bytes().all(|b| b.is_ascii_hexdigit()))
        || (s.len() == 32
            && s
                .bytes()
                .all(|b| b.is_ascii_alphabetic() || (b'2'..=b'7').contains(&b)))
}

fn query_params(magnet: &str) -> Vec<(String, String)> {
    let q = magnet.splitn(2, '?').nth(1).unwrap_or("");
    q.split('&')
        .filter_map(|kv| {
            let mut it = kv.splitn(2, '=');
            let k = it.next()?.to_string();
            let v = it.next().unwrap_or("");
            let v = urlencoding::decode(&v.replace('+', " "))
                .map(|c| c.into_owned())
                .unwrap_or_else(|_| v.to_string());
            Some((k, v))
        })
        .collect()
}

pub struct Parsed {
    pub info_hash: String,
    pub name: String,
    pub magnet: String,
}

pub fn parse_magnet(input: &str) -> Option<Parsed> {
    let s = input.trim();
    if !s.to_ascii_lowercase().starts_with("magnet:?") {
        return None;
    }
    let params = query_params(s);
    let xt = params
        .iter()
        .find(|(k, v)| k == "xt" && v.to_ascii_lowercase().starts_with("urn:btih:"))?;
    let raw = &xt.1[9..];
    if !is_info_hash(raw) {
        return None;
    }
    let info_hash = normalize_info_hash(raw);
    let name = params
        .iter()
        .find(|(k, _)| k == "dn")
        .map(|(_, v)| v.clone())
        .unwrap_or_else(|| info_hash.clone());
    Some(Parsed {
        info_hash,
        name,
        magnet: s.to_string(),
    })
}

/// A magnet link or a bare info hash.
pub fn parse_input(input: &str) -> Option<Parsed> {
    let s = input.trim();
    if let Some(p) = parse_magnet(s) {
        return Some(p);
    }
    if !is_info_hash(s) {
        return None;
    }
    let h = normalize_info_hash(s);
    Some(Parsed {
        magnet: build_magnet(&h, &h),
        name: h.clone(),
        info_hash: h,
    })
}

pub fn trackers_of(magnet: &str) -> Vec<String> {
    query_params(magnet)
        .into_iter()
        .filter(|(k, _)| k == "tr")
        .map(|(_, v)| v.trim().to_string())
        .filter(|v| !v.is_empty())
        .collect()
}

/// Append the trackers `other` carries that `primary` lacks.
pub fn merge_trackers(primary: &str, other: &str) -> String {
    let own = trackers_of(primary);
    let mut out = primary.trim().to_string();
    for t in trackers_of(other) {
        if !own.contains(&t) && !out.contains(&*urlencoding::encode(&t)) {
            out.push_str("&tr=");
            out.push_str(&urlencoding::encode(&t));
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_magnet_and_hash() {
        let m = build_magnet("abcdef0123456789abcdef0123456789abcdef01", "Some Name");
        let p = parse_magnet(&m).unwrap();
        assert_eq!(p.info_hash, "abcdef0123456789abcdef0123456789abcdef01");
        assert_eq!(p.name, "Some Name");
        assert!(parse_input("ABCDEF0123456789ABCDEF0123456789ABCDEF01").is_some());
        assert!(parse_input("the matrix").is_none());
        assert_eq!(trackers_of(&m).len(), TRACKERS.len());
    }

    #[test]
    fn base32_hash() {
        // 32 zero-bits groups -> all 'A' => 20 zero bytes
        let p = parse_input("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA").unwrap();
        assert_eq!(p.info_hash, "0".repeat(40));
    }

    #[test]
    fn merges_trackers() {
        let a = "magnet:?xt=urn:btih:00&tr=udp%3A%2F%2Fa";
        let b = "magnet:?xt=urn:btih:00&tr=udp%3A%2F%2Fb&tr=udp%3A%2F%2Fa";
        let m = merge_trackers(a, b);
        assert_eq!(trackers_of(&m), vec!["udp://a", "udp://b"]);
    }
}

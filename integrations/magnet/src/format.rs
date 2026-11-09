//! Human-readable sizes, speeds, durations and ages.

pub fn bytes(n: u64) -> String {
    const UNITS: [&str; 5] = ["B", "KB", "MB", "GB", "TB"];
    if n == 0 {
        return "—".into();
    }
    let mut v = n as f64;
    let mut i = 0;
    while v >= 1024.0 && i < UNITS.len() - 1 {
        v /= 1024.0;
        i += 1;
    }
    if i == 0 {
        format!("{n} B")
    } else if v >= 100.0 {
        format!("{v:.0} {}", UNITS[i])
    } else {
        format!("{v:.1} {}", UNITS[i])
    }
}

pub fn speed(bytes_per_sec: f64) -> String {
    if bytes_per_sec < 1.0 {
        return "0 B/s".into();
    }
    format!("{}/s", bytes(bytes_per_sec as u64))
}

pub fn duration(secs: u64) -> String {
    let (d, h, m, s) = (secs / 86400, secs / 3600 % 24, secs / 60 % 60, secs % 60);
    if d > 0 {
        format!("{d}d {h}h")
    } else if h > 0 {
        format!("{h}h {m}m")
    } else if m > 0 {
        format!("{m}m {s}s")
    } else {
        format!("{s}s")
    }
}

pub fn age(unix: Option<i64>) -> String {
    let Some(t) = unix.filter(|t| *t > 0) else {
        return "—".into();
    };
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0);
    let diff = (now - t).max(0);
    match diff {
        d if d < 3600 => format!("{}m", d / 60),
        d if d < 86400 => format!("{}h", d / 3600),
        d if d < 86400 * 30 => format!("{}d", d / 86400),
        d if d < 86400 * 365 => format!("{}mo", d / (86400 * 30)),
        d => format!("{}y", d / (86400 * 365)),
    }
}

/// "1.4 GiB", "700 MB", "1,234 MiB" -> bytes.
pub fn parse_size(s: &str) -> u64 {
    let s = s.trim().replace(',', "");
    let mut parts = s.split_whitespace();
    let Some(num) = parts.next().and_then(|n| n.parse::<f64>().ok()) else {
        return 0;
    };
    let unit = parts.next().unwrap_or("B").to_ascii_lowercase();
    let mul: f64 = match unit.trim_end_matches("ib").trim_end_matches('b') {
        "k" => 1024.0,
        "m" => 1024.0_f64.powi(2),
        "g" => 1024.0_f64.powi(3),
        "t" => 1024.0_f64.powi(4),
        _ => 1.0,
    };
    (num * mul) as u64
}

/// RFC 2822 date ("Tue, 04 Nov 2025 09:44:00 +0000") or "YYYY-MM-DD..." -> unix secs.
pub fn parse_date(s: &str) -> Option<i64> {
    let s = s.trim();
    if s.is_empty() {
        return None;
    }
    const MONTHS: [&str; 12] = [
        "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec",
    ];
    let (y, mo, d, rest): (i64, i64, i64, &str);
    if s.len() >= 10 && s.as_bytes()[4] == b'-' {
        y = s[0..4].parse().ok()?;
        mo = s[5..7].parse().ok()?;
        d = s[8..10].parse().ok()?;
        rest = s.get(11..).unwrap_or("");
    } else {
        let body = s.split_once(',').map(|x| x.1).unwrap_or(s).trim();
        let mut it = body.split_whitespace();
        d = it.next()?.parse().ok()?;
        let m = it.next()?.to_ascii_lowercase();
        mo = MONTHS.iter().position(|x| m.starts_with(x))? as i64 + 1;
        y = it.next()?.parse().ok()?;
        rest = it.next().unwrap_or("");
    }
    let mut hms = rest.split(|c| c == ':' || c == ' ' || c == '+' || c == 'Z' || c == '.');
    let h: i64 = hms.next().and_then(|x| x.parse().ok()).unwrap_or(0);
    let mi: i64 = hms.next().and_then(|x| x.parse().ok()).unwrap_or(0);
    let se: i64 = hms.next().and_then(|x| x.parse().ok()).unwrap_or(0);
    // days from civil (Howard Hinnant)
    let yy = if mo <= 2 { y - 1 } else { y };
    let era = yy.div_euclid(400);
    let yoe = yy - era * 400;
    let mp = (mo + 9) % 12;
    let doy = (153 * mp + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    let days = era * 146097 + doe - 719468;
    Some(days * 86400 + h * 3600 + mi * 60 + se)
}

pub fn unescape(s: &str) -> String {
    s.replace("&#038;", "&")
        .replace("&#38;", "&")
        .replace("&amp;", "&")
        .replace("&#8211;", "-")
        .replace("&#8212;", "-")
        .replace("&#8217;", "'")
        .replace("&#039;", "'")
        .replace("&#39;", "'")
        .replace("&apos;", "'")
        .replace("&#8220;", "\"")
        .replace("&#8221;", "\"")
        .replace("&quot;", "\"")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sizes() {
        assert_eq!(parse_size("1.5 GiB"), 1610612736);
        assert_eq!(parse_size("700 MiB"), 734003200);
        assert_eq!(bytes(1610612736), "1.5 GB");
    }

    #[test]
    fn dates() {
        assert_eq!(parse_date("Thu, 01 Jan 1970 00:00:00 +0000"), Some(0));
        assert_eq!(parse_date("2000-03-01T00:00:00Z"), Some(951868800));
        assert_eq!(parse_date("Wed, 04 Nov 2026 10:00:00 -0000"), Some(1793786400));
    }
}

//! Colors. Follows the active SpectrumOS palette when there is one
//! (`$XDG_CACHE_HOME/spectrumos/theme/current/palette.json`, schema v1), and
//! falls back to Magnet's own palette everywhere else.
//!
//! The palette is re-read periodically through the `current` symlink, so a
//! wallpaper change recolors a running Magnet within a couple of seconds.

use std::path::PathBuf;
use std::sync::RwLock;

use ratatui::style::Color;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Theme {
    /// Main canvas. `Reset` keeps the terminal's own background.
    pub bg: Color,
    /// Popups and overlays.
    pub surface: Color,
    /// Selected row fill.
    pub selection: Color,
    /// Borders and separators.
    pub rule: Color,
    pub fg: Color,
    pub muted: Color,
    pub accent: Color,
    pub accent_alt: Color,
    /// Text drawn on an accent fill.
    pub on_accent: Color,
    pub success: Color,
    pub warning: Color,
    pub error: Color,
    /// Name of the palette in use, for display.
    pub spectrum: bool,
}

impl Theme {
    pub const FALLBACK: Theme = Theme {
        bg: Color::Reset,
        surface: Color::Reset,
        selection: Color::Rgb(0x3a, 0x2a, 0x22),
        rule: Color::Rgb(0x5a, 0x51, 0x4b),
        fg: Color::Rgb(0xec, 0xe4, 0xdc),
        muted: Color::Rgb(0x8a, 0x7f, 0x76),
        accent: Color::Rgb(0xff, 0x8a, 0x4c),
        accent_alt: Color::Rgb(0xff, 0xb8, 0x8c),
        on_accent: Color::Black,
        success: Color::Rgb(0x86, 0xd6, 0xa2),
        warning: Color::Rgb(0xf0, 0xc5, 0x60),
        error: Color::Rgb(0xee, 0x7d, 0x92),
        spectrum: false,
    };

    /// Parse a SpectrumOS palette.json. None if it isn't a valid schema v1 palette.
    pub fn from_spectrum(json: &str) -> Option<Theme> {
        let v: serde_json::Value = serde_json::from_str(json).ok()?;
        if v["schema_version"].as_u64() != Some(1) {
            return None;
        }
        let roles = v["roles"].as_object()?;
        let role = |k: &str| roles.get(k).and_then(|x| x.as_str()).and_then(hex);
        let bg = role("background")?;
        let surface = role("surface")?;
        let surface_alt = role("surface_alt")?;
        let fg = role("foreground")?;
        let muted = role("muted")?;
        let accent = role("accent")?;
        let accent_alt = role("accent_alt")?;
        Some(Theme {
            bg: rgb(bg),
            surface: rgb(surface),
            // A selection tinted toward the accent reads better than a bare
            // surface_alt, which can sit very close to the background.
            selection: rgb(mix(surface_alt, accent, 0.22)),
            // Separators: surface_alt, lifted toward muted so borders stay visible.
            rule: rgb(mix(surface_alt, muted, 0.5)),
            fg: rgb(fg),
            muted: rgb(muted),
            accent: rgb(accent),
            accent_alt: rgb(accent_alt),
            on_accent: rgb(bg),
            success: role("success").map(rgb).unwrap_or(Self::FALLBACK.success),
            warning: role("warning").map(rgb).unwrap_or(Self::FALLBACK.warning),
            error: role("error").map(rgb).unwrap_or(Self::FALLBACK.error),
            spectrum: true,
        })
    }

    /// Decorative color `t` of the way from accent to accent_alt.
    pub fn blend(&self, t: f32) -> Color {
        match (self.accent, self.accent_alt) {
            (Color::Rgb(a, b, c), Color::Rgb(x, y, z)) => rgb(mix((a, b, c), (x, y, z), t)),
            _ => self.accent,
        }
    }

    /// Decorative color `t` of the way from accent toward the foreground.
    pub fn toward_fg(&self, base: Color, t: f32) -> Color {
        match (base, self.fg) {
            (Color::Rgb(a, b, c), Color::Rgb(x, y, z)) => rgb(mix((a, b, c), (x, y, z), t)),
            _ => base,
        }
    }
}

type Rgb = (u8, u8, u8);

fn hex(s: &str) -> Option<Rgb> {
    let s = s.trim().strip_prefix('#')?;
    if s.len() != 6 {
        return None;
    }
    let n = u32::from_str_radix(s, 16).ok()?;
    Some(((n >> 16) as u8, (n >> 8) as u8, n as u8))
}

fn rgb((r, g, b): Rgb) -> Color {
    Color::Rgb(r, g, b)
}

fn mix(a: Rgb, b: Rgb, t: f32) -> Rgb {
    let l = |x: u8, y: u8| (x as f32 + (y as f32 - x as f32) * t).round() as u8;
    (l(a.0, b.0), l(a.1, b.1), l(a.2, b.2))
}

fn palette_path() -> Option<PathBuf> {
    let cache = std::env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .or_else(|| dirs::home_dir().map(|h| h.join(".cache")))?;
    Some(cache.join("spectrumos/theme/current/palette.json"))
}

static THEME: RwLock<Theme> = RwLock::new(Theme::FALLBACK);
static LAST: RwLock<Option<String>> = RwLock::new(None);

pub fn get() -> Theme {
    *THEME.read().unwrap()
}

/// Re-read the palette through `current` (never a resolved generation path).
/// Returns true when the colors changed. Any failure keeps the fallback, so a
/// missing or malformed palette never stops Magnet from starting.
pub fn reload() -> bool {
    let raw = palette_path().and_then(|p| std::fs::read_to_string(p).ok());
    if *LAST.read().unwrap() == raw {
        return false;
    }
    let next = raw.as_deref().and_then(Theme::from_spectrum).unwrap_or(Theme::FALLBACK);
    *LAST.write().unwrap() = raw;
    let mut cur = THEME.write().unwrap();
    let changed = *cur != next;
    *cur = next;
    changed
}

#[cfg(test)]
mod tests {
    use super::*;

    const SAMPLE: &str = r##"{"schema_version":1,"variant":"dark","roles":{
        "background":"#101218","surface":"#191c24","surface_alt":"#252a35",
        "foreground":"#e9edf5","muted":"#9ca6b8","accent":"#76b7ff","accent_alt":"#c49aff",
        "success":"#78dba9","warning":"#f2c66d","error":"#ff8c9a"}}"##;

    #[test]
    fn parses_spectrum_palette() {
        let t = Theme::from_spectrum(SAMPLE).unwrap();
        assert_eq!(t.accent, Color::Rgb(0x76, 0xb7, 0xff));
        assert_eq!(t.bg, Color::Rgb(0x10, 0x12, 0x18));
        assert_eq!(t.on_accent, t.bg);
        assert!(t.spectrum);
    }

    #[test]
    fn rejects_bad_palettes() {
        assert!(Theme::from_spectrum("not json").is_none());
        assert!(Theme::from_spectrum(&SAMPLE.replace("\"schema_version\":1", "\"schema_version\":2")).is_none());
        assert!(Theme::from_spectrum(&SAMPLE.replace("#76b7ff", "blue")).is_none());
    }
}

from __future__ import annotations

import json

from .palette import Palette

# Kvantum reads every widget as named nine-patch pieces (a center, four edges, and four
# corners per state) and takes each corner's pixel size from frame.top/bottom/left/right in
# the .kvconfig. A single proportionally-rounded <rect> gives Kvantum no real frame data, so
# it falls back to its own default geometry and a 25% corner on a small square tile reads as
# a near-circle instead of a subtly rounded rectangle -- the reported "circle button" bug.
KVANTUM_BUTTON_RADIUS = 4
KVANTUM_TOOLTIP_RADIUS = 3
KVANTUM_INDICATOR_SIZE = 14

# The monospace family used by the terminal (Kitty, Alacritty), Waybar, Wofi, the Eww
# control center, and Dunst notification icons -- selectable from a fixed, verified-
# installed set (see FONT_FAMILIES in cli.py) rather than an arbitrary free-text family
# name, so a typo or an uninstalled font can never silently fall back to something else.
DEFAULT_FONT_FAMILY = "JetBrainsMono Nerd Font"


def render_hyprland(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    lines = [
        "hl.config({",
        "    general = {",
        "        col = {",
        f'            active_border = {{ colors = {{ "rgb({palette.bare("accent")})", "rgb({palette.bare("accent_alt")})" }}, angle = 45 }},',
        f'            inactive_border = "rgb({palette.bare("muted")})",',
        "        },",
        "    },",
        "})",
        "",
    ]
    return "\n".join(lines)


def render_kitty(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    ansi_roles = (
        "background",
        "error",
        "success",
        "warning",
        "accent_alt",
        "accent",
        "muted",
        "foreground",
        "surface_alt",
        "error",
        "success",
        "warning",
        "accent_alt",
        "accent",
        "muted",
        "foreground",
    )
    lines = [
        f"font_family {font_family}",
        f"font_size {font_size}",
        f"background {palette.color('background')}",
        f"foreground {palette.color('foreground')}",
        f"selection_background {palette.color('accent')}",
        f"selection_foreground {palette.color('background')}",
        f"cursor {palette.color('accent')}",
        f"cursor_text_color {palette.color('background')}",
        f"url_color {palette.color('accent_alt')}",
        "",
    ]
    lines.extend(f"color{index} {palette.color(role)}" for index, role in enumerate(ansi_roles))
    lines.append("")
    return "\n".join(lines)


def render_cava(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return "\n".join((
        "[color]",
        f"background = '{palette.color('background')}'",
        f"foreground = '{palette.color('accent')}'",
        "gradient = 1",
        f"gradient_color_1 = '{palette.color('accent')}'",
        f"gradient_color_2 = '{palette.color('accent_alt')}'",
        f"gradient_color_3 = '{palette.color('foreground')}'",
        "",
    ))


def render_alacritty(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    ansi_roles = {
        "black": "surface_alt",
        "red": "error",
        "green": "success",
        "yellow": "warning",
        "blue": "accent_alt",
        "magenta": "accent",
        "cyan": "muted",
        "white": "foreground",
    }
    lines = [
        "[font]",
        f'normal = {{ family = "{font_family}", style = "Regular" }}',
        f'bold = {{ family = "{font_family}", style = "Bold" }}',
        f'italic = {{ family = "{font_family}", style = "Italic" }}',
        f"size = {font_size}.0",
        "",
        "[colors.primary]",
        f'background = "{palette.color("background")}"',
        f'foreground = "{palette.color("foreground")}"',
        "",
        "[colors.cursor]",
        f'text = "{palette.color("background")}"',
        f'cursor = "{palette.color("accent")}"',
        "",
        "[colors.selection]",
        f'text = "{palette.color("background")}"',
        f'background = "{palette.color("accent")}"',
        "",
        "[colors.normal]",
    ]
    lines.extend(f'{name} = "{palette.color(role)}"' for name, role in ansi_roles.items())
    lines.extend(("", "[colors.bright]"))
    lines.extend(f'{name} = "{palette.color(role)}"' for name, role in ansi_roles.items())
    lines.append("")
    return "\n".join(lines)


def render_neovim(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    groups = {
        "Normal": {"fg": "foreground", "bg": "background"},
        "NormalFloat": {"fg": "foreground", "bg": "surface"},
        "FloatBorder": {"fg": "accent", "bg": "surface"},
        "Cursor": {"fg": "background", "bg": "foreground"},
        "CursorLine": {"bg": "surface"},
        "CursorLineNr": {"fg": "accent", "bg": "surface", "bold": True},
        "LineNr": {"fg": "muted", "bg": "background"},
        "SignColumn": {"fg": "muted", "bg": "background"},
        "ColorColumn": {"bg": "surface"},
        "Visual": {"fg": "background", "bg": "accent"},
        "Search": {"fg": "background", "bg": "accent_alt"},
        "IncSearch": {"fg": "background", "bg": "accent_alt"},
        "MatchParen": {"fg": "background", "bg": "accent", "bold": True},
        "Pmenu": {"fg": "foreground", "bg": "surface"},
        "PmenuSel": {"fg": "background", "bg": "accent", "bold": True},
        "StatusLine": {"fg": "foreground", "bg": "surface_alt"},
        "StatusLineNC": {"fg": "muted", "bg": "surface"},
        "TabLine": {"fg": "muted", "bg": "surface"},
        "TabLineSel": {"fg": "background", "bg": "accent", "bold": True},
        "WinSeparator": {"fg": "surface_alt", "bg": "background"},
        "Directory": {"fg": "accent"},
        "Title": {"fg": "accent", "bold": True},
        "Comment": {"fg": "muted", "italic": True},
        "Constant": {"fg": "accent_alt"},
        "String": {"fg": "accent"},
        "Character": {"fg": "accent"},
        "Number": {"fg": "accent_alt"},
        "Boolean": {"fg": "accent_alt"},
        "Identifier": {"fg": "foreground"},
        "Function": {"fg": "accent"},
        "Statement": {"fg": "accent_alt"},
        "Keyword": {"fg": "accent_alt", "bold": True},
        "Operator": {"fg": "accent_alt"},
        "PreProc": {"fg": "accent_alt"},
        "Type": {"fg": "accent"},
        "Special": {"fg": "accent_alt"},
        "Underlined": {"fg": "accent", "underline": True},
        "Error": {"fg": "error"},
        "ErrorMsg": {"fg": "error", "bold": True},
        "WarningMsg": {"fg": "warning"},
        "Todo": {"fg": "background", "bg": "warning", "bold": True},
        "DiagnosticError": {"fg": "error"},
        "DiagnosticWarn": {"fg": "warning"},
        "DiagnosticInfo": {"fg": "accent"},
        "DiagnosticHint": {"fg": "success"},
        "DiffAdd": {"fg": "success", "bg": "surface"},
        "DiffChange": {"fg": "warning", "bg": "surface"},
        "DiffDelete": {"fg": "error", "bg": "surface"},
        "GitSignsAdd": {"fg": "success"},
        "GitSignsChange": {"fg": "warning"},
        "GitSignsDelete": {"fg": "error"},
    }
    terminal_roles = (
        "background", "error", "success", "warning", "accent_alt", "accent", "muted", "foreground",
        "surface_alt", "error", "success", "warning", "accent_alt", "accent", "muted", "foreground",
    )
    lines = [
        f'vim.o.background = "{palette.variant}"',
        "vim.cmd(\"highlight clear\")",
        'vim.g.colors_name = "spectrum"',
        "local groups = {",
    ]
    for name, attributes in groups.items():
        values = []
        for key, value in attributes.items():
            if isinstance(value, bool):
                values.append(f"{key} = {str(value).lower()}")
            else:
                values.append(f'{key} = "{palette.color(value)}"')
        lines.append(f'  ["{name}"] = {{ {", ".join(values)} }},')
    lines.extend((
        "}",
        "for name, attributes in pairs(groups) do",
        "  vim.api.nvim_set_hl(0, name, attributes)",
        "end",
    ))
    lines.extend(
        f'vim.g.terminal_color_{index} = "{palette.color(role)}"'
        for index, role in enumerate(terminal_roles)
    )
    lines.append("")
    return "\n".join(lines)


def render_dunst(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return "\n".join(
        (
            "[global]",
            "    monitor = 0",
            "    follow = keyboard",
            "    width = (320, 420)",
            "    height = (56, 180)",
            "    origin = top-right",
            "    offset = (12, 42)",
            "    notification_limit = 6",
            "    progress_bar = true",
            "    progress_bar_height = 7",
            "    progress_bar_frame_width = 0",
            "    progress_bar_min_width = 180",
            "    progress_bar_max_width = 360",
            "    progress_bar_corner_radius = 4",
            f'    highlight = "{palette.color("accent")}"',
            "    indicate_hidden = true",
            "    separator_height = 0",
            "    padding = 12",
            "    horizontal_padding = 14",
            "    text_icon_padding = 12",
            "    frame_width = 2",
            "    gap_size = 8",
            "    corner_radius = 10",
            f"    font = {font_family} {font_size}",
            f'    frame_color = "{palette.color("accent")}"',
            f'    separator_color = "{palette.color("surface_alt")}"',
            f'    format = "<span size=\'small\' foreground=\'{palette.color("muted")}\'>%a</span>\\n<b>%s</b>\\n%b"',
            "    markup = full",
            "    alignment = left",
            "    vertical_alignment = center",
            "    ellipsize = middle",
            "    stack_duplicates = true",
            "    hide_duplicate_count = false",
            "    show_indicators = true",
            "    icon_position = left",
            "    min_icon_size = 32",
            "    max_icon_size = 48",
            "    icon_corner_radius = 8",
            "    enable_recursive_icon_lookup = true",
            '    icon_theme = "Adwaita, hicolor"',
            "    icon_path = /usr/share/icons/Adwaita/symbolic/status:/usr/share/icons/Adwaita/symbolic/apps:/usr/share/icons/hicolor/scalable/apps:/usr/share/pixmaps",
            "    history_length = 50",
            "    browser = /usr/bin/xdg-open",
            "    mouse_left_click = do_action, close_current",
            "    mouse_middle_click = close_current",
            "    mouse_right_click = context",
            "",
            "[urgency_low]",
            f'    background = "{palette.color("surface")}"',
            f'    foreground = "{palette.color("muted")}"',
            f'    frame_color = "{palette.color("surface_alt")}"',
            "    timeout = 4",
            "    default_icon = $XDG_CACHE_HOME/spectrumos/theme/current/dunst-info.svg",
            "",
            "[urgency_normal]",
            f'    background = "{palette.color("surface")}"',
            f'    foreground = "{palette.color("foreground")}"',
            f'    frame_color = "{palette.color("accent")}"',
            "    timeout = 7",
            "    default_icon = $XDG_CACHE_HOME/spectrumos/theme/current/dunst-info.svg",
            "",
            "[urgency_critical]",
            f'    background = "{palette.color("background")}"',
            f'    foreground = "{palette.color("foreground")}"',
            f'    frame_color = "{palette.color("error")}"',
            f'    highlight = "{palette.color("error")}"',
            "    timeout = 0",
            "    default_icon = $XDG_CACHE_HOME/spectrumos/theme/current/dunst-warning.svg",
            "",
            "[spectrum]",
            "    appname = SpectrumOS",
            "    new_icon = $XDG_CACHE_HOME/spectrumos/theme/current/dunst-system.svg",
            "    set_stack_tag = spectrum",
            "",
            "[volume]",
            "    appname = Spectrum Volume",
            "    new_icon = $XDG_CACHE_HOME/spectrumos/theme/current/dunst-volume.svg",
            "    set_stack_tag = spectrum-volume",
            "    format = \"<b>%s</b>\"",
            "    progress_bar = true",
            "    timeout = 2",
            "",
            "[brightness]",
            "    appname = Spectrum Brightness",
            "    new_icon = $XDG_CACHE_HOME/spectrumos/theme/current/dunst-brightness.svg",
            "    set_stack_tag = spectrum-brightness",
            "    format = \"<b>%s</b>\"",
            "    progress_bar = true",
            "    timeout = 2",
            "",
            "[network]",
            "    appname = NetworkManager",
            "    new_icon = network-wireless-symbolic",
            "",
            "[bluetooth]",
            "    appname = blueman",
            "    new_icon = bluetooth-symbolic",
            "",
            "[zen-browser]",
            "    appname = Zen Browser",
            "    new_icon = zen-browser",
            "",
            "[chromium]",
            "    appname = Chromium",
            "    new_icon = chromium",
            "",
            "[discord]",
            "    appname = Discord",
            "    new_icon = discord",
            "",
            "[telegram]",
            "    appname = TelegramDesktop",
            "    new_icon = telegram",
            "",
            "[spotify]",
            "    appname = Spotify",
            "    new_icon = spotify-client",
            "    set_stack_tag = media",
            "",
            "[steam]",
            "    appname = Steam",
            "    new_icon = steam",
            "",
            "[screenshot]",
            "    summary = *Screenshot*",
            "    new_icon = camera-photo-symbolic",
            "",
            "[download]",
            "    summary = *Download*",
            "    new_icon = folder-download-symbolic",
            f'    frame_color = "{palette.color("success")}"',
            "",
            "[battery-warning]",
            "    summary = *Battery*",
            f'    frame_color = "{palette.color("warning")}"',
            "",
        )
    )


def _dunst_icon(color: str, body: str) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24">
  <g fill="{color}">{body}</g>
</svg>
"""


def render_dunst_volume_icon(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return _dunst_icon(
        palette.color("foreground"),
        '<path d="M3 9v6h4l5 4V5L7 9H3z"/><path d="M15 8.5a5 5 0 0 1 0 7v-2.2a3 3 0 0 0 0-2.6V8.5z"/><path d="M17.7 5.8a9 9 0 0 1 0 12.4l-1.4-1.4a7 7 0 0 0 0-9.6l1.4-1.4z"/>',
    )


def render_dunst_brightness_icon(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return _dunst_icon(
        palette.color("foreground"),
        '<circle cx="12" cy="12" r="4"/><path d="M11 1h2v4h-2zM11 19h2v4h-2zM1 11h4v2H1zM19 11h4v2h-4zM4.2 5.6l1.4-1.4 2.8 2.8L7 8.4zM15.6 17l1.4-1.4 2.8 2.8-1.4 1.4zM15.6 7l2.8-2.8 1.4 1.4L17 8.4zM4.2 18.4L7 15.6 8.4 17l-2.8 2.8z"/>',
    )


def render_dunst_info_icon(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return _dunst_icon(
        palette.color("foreground"),
        '<circle cx="12" cy="12" r="10"/><rect x="11" y="10" width="2" height="7" fill="' + palette.color("background") + '"/><circle cx="12" cy="7" r="1.2" fill="' + palette.color("background") + '"/>',
    )


def render_dunst_warning_icon(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return _dunst_icon(
        palette.color("error"),
        '<path d="M12 2 1 21h22L12 2zm-1 6h2v7h-2V8zm1 10.5a1.3 1.3 0 1 1 0-2.6 1.3 1.3 0 0 1 0 2.6z"/>',
    )


def render_dunst_system_icon(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return _dunst_icon(
        palette.color("foreground"),
        '<path d="M4 5h16v11H4V5zm2 2v7h12V7H6zm3 11h6l2 2H7l2-2z"/>',
    )


def _waybar_theme(theme: str) -> str:
    if theme == "prism":
        return """
#workspaces button {
    background: @surface_alt;
    color: @foreground;
}

#network,
#bluetooth,
#custom-displays,
#custom-weather {
    background: @accent;
    color: @background;
}

#pulseaudio,
#mpris,
#custom-media-prev,
#custom-media-play-pause,
#custom-media-next {
    background: @accent_alt;
    color: @background;
}

#clock,
#custom-font-size,
#custom-pomodoro {
    background: @accent;
    color: @background;
}

#cpu,
#memory,
#custom-gpu,
#custom-cpu-temp,
#custom-refresh,
#disk,
#temperature {
    background: @surface_alt;
    color: @foreground;
}

#backlight,
#battery,
#idle_inhibitor,
#custom-keep-awake,
#custom-performance {
    background: @accent_alt;
    color: @background;
}

#tray {
    background: @surface_alt;
}
"""
    if theme == "tonal":
        return """
#workspaces button {
    background: alpha(@accent_alt, 0.18);
    color: @foreground;
}

#clock,
#custom-font-size,
#custom-pomodoro,
#mpris,
#custom-media-prev,
#custom-media-play-pause,
#custom-media-next {
    background: alpha(@accent, 0.34);
}

#network,
#bluetooth,
#custom-displays,
#pulseaudio {
    background: alpha(@accent_alt, 0.34);
}

#cpu,
#memory,
#custom-gpu,
#custom-cpu-temp,
#custom-refresh,
#disk,
#temperature {
    background: alpha(@accent_alt, 0.26);
}

#backlight,
#battery,
#idle_inhibitor,
#custom-keep-awake,
#custom-performance,
#custom-weather {
    background: alpha(@accent, 0.28);
}

#tray {
    background: @surface_alt;
    color: @accent;
}
"""
    return """
#workspaces,
#clock,
#mpris,
#custom-pomodoro,
#custom-weather,
#custom-gpu,
#custom-cpu-temp,
#custom-refresh,
#custom-displays,
#custom-font-size,
#custom-media-prev,
#custom-media-play-pause,
#custom-media-next,
#idle_inhibitor,
#custom-keep-awake,
#custom-performance,
#bluetooth,
#network,
#pulseaudio,
#battery,
#cpu,
#memory,
#temperature,
#disk,
#backlight,
#tray {
    background: @surface;
    color: @foreground;
}
"""


def _render_waybar(palette: Palette, square: bool, theme: str, font_size: int, font_family: str) -> str:
    container_radius = 0 if square else 10
    item_radius = 0 if square else 7
    tooltip_radius = 0 if square else 8
    # md-coffee/md-coffee_off/md-speedometer/fa-scale_balanced (custom-keep-awake and
    # custom-performance's four glyphs) all paint noticeably past their own advance width
    # in every Nerd Font SpectrumOS ships -- measured directly off the font files with
    # fontTools: ink runs to ~1704/2048 em for the three "md-" glyphs and ~2360/2048 em for
    # fa-scale_balanced (the "balanced" state, worst offender at roughly double its own
    # box), against every other icon's ink comfortably inside its 1200/2048 advance. Pango
    # sizes the module's background pill from the advance width alone, so that overflow
    # bled past the shared 8px right padding into (or past) the pill's edge -- left bearing
    # on all four glyphs is negligible, so only the right side needed the extra room.
    wide_icon_padding = 8 + round(font_size * 0.6)
    return f"""@define-color background {palette.color('background')};
@define-color surface {palette.color('surface')};
@define-color surface_alt {palette.color('surface_alt')};
@define-color foreground {palette.color('foreground')};
@define-color muted {palette.color('muted')};
@define-color accent {palette.color('accent')};
@define-color accent_alt {palette.color('accent_alt')};
@define-color success {palette.color('success')};
@define-color warning {palette.color('warning')};
@define-color error {palette.color('error')};

* {{
    border: none;
    min-height: 0;
    font-family: "{font_family}", monospace;
    font-size: {font_size}px;
    font-weight: 600;
}}

window#waybar {{
    background: transparent;
    color: @foreground;
}}

window#waybar > box {{
    background: transparent;
}}

.modules-left,
.modules-center,
.modules-right {{
    background: transparent;
    border: none;
    border-radius: {container_radius}px;
    padding: 3px 5px;
}}

#workspaces button {{
    background: transparent;
    color: @muted;
    border-radius: {item_radius}px;
    min-width: 26px;
    padding: 0 5px;
}}

#workspaces button:hover {{
    background: @surface_alt;
    color: @foreground;
}}

#workspaces button.active {{
    background: @accent;
    color: @background;
}}

#workspaces button.urgent {{
    background: @error;
    color: @background;
}}

/* #workspaces and #window are containers, not individual per-status-module chips, so they
   sit outside the shared #clock, #cpu, ... block below that already carries this same
   border-radius -- without restating it here, both stayed square-cornered no matter which
   shape (Spectrum/Square) was selected, since a GTK box has no rounding by default. */
#workspaces,
#window {{
    border-radius: {item_radius}px;
}}

#window {{
    background: @surface;
    color: @muted;
    padding: 0 9px;
}}

#clock,
#mpris,
#custom-pomodoro,
#custom-weather,
#custom-gpu,
#custom-cpu-temp,
#custom-refresh,
#custom-displays,
#custom-recorder,
#custom-font-size,
#custom-media-prev,
#custom-media-play-pause,
#custom-media-next,
#custom-cava,
#idle_inhibitor,
#custom-keep-awake,
#custom-performance,
#bluetooth,
#network,
#pulseaudio,
#battery,
#cpu,
#memory,
#temperature,
#disk,
#backlight,
#tray {{
    background: transparent;
    color: @foreground;
    border-radius: {item_radius}px;
    padding: 0 8px;
}}

{_waybar_theme(theme)}

#clock {{
    min-width: 58px;
}}

/* See wide_icon_padding above: these two glyphs' ink overflows their own advance width,
   so they get extra room on the right only -- the left side was never the problem. */
#custom-keep-awake,
#custom-performance {{
    padding: 0 {wide_icon_padding}px 0 8px;
}}

#idle_inhibitor.activated,
#custom-keep-awake.active {{
    background: @accent;
    color: @background;
}}

/* Only "performance" gets the highlight, matching the Eww header icon's own
   header-icon.active convention -- "balanced" is the everyday default and stays the
   plain chip look rather than competing for attention. */
#custom-performance.performance {{
    background: @accent;
    color: @background;
}}

#network.disconnected,
#pulseaudio.muted {{
    color: @muted;
}}

#battery.charging,
#battery.plugged {{
    color: @success;
}}

#battery.warning:not(.charging) {{
    color: @warning;
}}

#battery.critical:not(.charging) {{
    background: @error;
    color: @background;
}}

#temperature.critical {{
    color: @error;
}}

#custom-pomodoro.work {{
    background: @accent;
    color: @background;
}}

#custom-pomodoro.break {{
    color: @success;
}}

#custom-font-size {{
    font-weight: 800;
    min-width: 24px;
}}

#custom-recorder.recording {{
    background: @error;
    color: @background;
    font-weight: 800;
}}

#custom-recorder.idle {{
    min-width: 0;
    padding: 0;
}}

#custom-pomodoro.paused,
#custom-pomodoro.break-paused {{
    color: @warning;
}}

#custom-gpu.critical {{
    color: @error;
}}

#custom-cpu-temp.critical {{
    color: @error;
}}

#custom-weather.unavailable,
#custom-gpu.unavailable,
#custom-cpu-temp.unavailable,
#custom-refresh.unavailable,
#custom-performance.unavailable {{
    min-width: 0;
    padding: 0;
}}

#custom-cava {{
    background: @background;
    color: @foreground;
    min-width: 84px;
}}

#custom-media-prev,
#custom-media-play-pause,
#custom-media-next {{
    min-width: 20px;
}}

/* GTK's own default theme already assigns tooltip/calendar text a font-size with higher
   selector specificity than the universal `*` rule above, so the global font-size control
   would silently lose to it without being restated explicitly here. */
tooltip {{
    background: @surface;
    color: @foreground;
    border: 1px solid @accent;
    border-radius: {tooltip_radius}px;
    font-size: {font_size}px;
}}

tooltip label {{
    color: @foreground;
    font-size: {font_size}px;
}}

/* The clock's hover/click tooltip embeds a native GTK calendar ({{calendar}} in
   tooltip-format); style it here so it follows the active palette instead of GTK's
   unstyled default, the same way every other module already does. Children (.header,
   .button, :selected) inherit {font_size}px from this rule rather than restating it. */
calendar {{
    background: @surface;
    color: @foreground;
    border-radius: {tooltip_radius}px;
    padding: 6px;
    font-size: {font_size}px;
}}

calendar.header {{
    color: @accent_alt;
    font-weight: 700;
}}

calendar:indeterminate {{
    color: @muted;
}}

calendar.button {{
    color: @muted;
    border-radius: {item_radius}px;
}}

calendar.button:hover {{
    background: @surface_alt;
    color: @foreground;
}}

calendar:selected {{
    background: @accent;
    color: @background;
    border-radius: {item_radius}px;
    font-weight: 700;
}}
"""


def render_waybar_spectrum_unified(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return _render_waybar(palette, False, "unified", font_size, font_family)


def render_waybar_spectrum_tonal(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return _render_waybar(palette, False, "tonal", font_size, font_family)


def render_waybar_spectrum_prism(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return _render_waybar(palette, False, "prism", font_size, font_family)


def render_waybar_square_unified(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return _render_waybar(palette, True, "unified", font_size, font_family)


def render_waybar_square_tonal(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return _render_waybar(palette, True, "tonal", font_size, font_family)


def render_waybar_square_prism(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return _render_waybar(palette, True, "prism", font_size, font_family)


render_waybar_spectrum = render_waybar_spectrum_unified
render_waybar_square = render_waybar_square_unified


def _render_wofi(palette: Palette, wallpaper: bool, font_size: int, font_family: str) -> str:
    entry_padding = 10 if wallpaper else 6
    image_margin = 7 if wallpaper else 8
    return f"""* {{
    font-family: "{font_family}", monospace;
    font-size: {font_size}px;
}}

#window {{
    background-color: alpha({palette.color('background')}, 0.97);
    color: {palette.color('foreground')};
    border: 1px solid alpha({palette.color('accent')}, 0.4);
    border-radius: 11px;
}}

#outer-box {{
    padding: 10px;
}}

#input {{
    margin: 0 0 8px 0;
    padding: 8px 10px;
    background-color: {palette.color('surface')};
    color: {palette.color('foreground')};
    border: 1px solid alpha({palette.color('accent')}, 0.3);
    border-radius: 7px;
    caret-color: {palette.color('accent')};
}}

#input:focus {{
    border-color: {palette.color('accent')};
}}

#scroll {{
    background-color: transparent;
}}

#scroll scrollbar {{
    min-width: 0;
    min-height: 0;
    opacity: 0;
}}

#scroll undershoot,
#scroll overshoot {{
    background: none;
}}

#inner-box {{
    background-color: transparent;
}}

#entry {{
    padding: {entry_padding}px;
    margin: 2px;
    background-color: transparent;
    color: {palette.color('foreground')};
    border-radius: 7px;
}}

#entry:hover {{
    background-color: alpha({palette.color('accent_alt')}, 0.18);
}}

#entry:selected {{
    background-image: linear-gradient(135deg, {palette.color('accent')}, {palette.color('accent_alt')});
    color: {palette.color('background')};
}}

#text {{
    color: {palette.color('foreground')};
}}

#entry:selected #text {{
    color: {palette.color('background')};
}}

#img {{
    margin-right: {image_margin}px;
    border-radius: 7px;
    border: 1px solid alpha({palette.color('accent_alt')}, 0.35);
}}

tooltip {{
    background-color: {palette.color('surface')};
    color: {palette.color('foreground')};
    border: 1px solid {palette.color('accent')};
}}
"""


def render_wofi(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return _render_wofi(palette, False, font_size, font_family)


def render_wofi_wallpaper(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return _render_wofi(palette, True, font_size, font_family)


def render_eww(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return f"""* {{
  all: unset;
  font-family: "{font_family}", monospace;
  font-size: {font_size}px;
}}

.spectrum-panel {{
  padding: 24px;
  background: {palette.color('background')};
  color: {palette.color('foreground')};
  border: 1px solid {palette.color('surface_alt')};
  border-radius: 18px;
}}

.panel-heading {{ padding: 4px 6px 12px; }}
.panel-title {{ color: {palette.color('accent')}; font-size: {round(font_size * 1.5)}px; font-weight: 700; }}
.panel-subtitle, .action-subtitle, .migration-note {{ color: {palette.color('muted')}; }}

.network-card {{
  padding: 12px;
  background: {palette.color('surface')};
  border: 1px solid {palette.color('surface_alt')};
  border-radius: 10px;
}}
.network-icon {{ color: {palette.color('accent')}; font-size: {round(font_size * 1.5)}px; min-width: 36px; }}
.network-title {{ font-weight: 700; }}
.network-status {{ color: {palette.color('muted')}; }}
.network-toggle, .network-button {{
  padding: 7px 10px;
  background: {palette.color('surface_alt')};
  color: {palette.color('foreground')};
  border-radius: 7px;
}}
.network-toggle:hover, .network-button:hover {{
  background: {palette.color('accent')};
  color: {palette.color('background')};
}}
.access-point-summary {{ color: {palette.color('muted')}; padding-top: 3px; }}

.spectrum-action {{
  padding: 11px 12px;
  background: {palette.color('surface')};
  border: 1px solid {palette.color('surface_alt')};
  border-radius: 10px;
}}
.category-row {{ min-height: 92px; }}

.spectrum-action:hover, .spectrum-action:focus {{
  background: {palette.color('accent')};
  color: {palette.color('background')};
}}

.action-icon {{
  min-width: 28px;
  color: {palette.color('accent_alt')};
  font-size: {round(font_size * 1.5)}px;
}}

.spectrum-action:hover .action-icon,
.spectrum-action:focus .action-icon,
.spectrum-action:hover .action-subtitle,
.spectrum-action:focus .action-subtitle {{ color: {palette.color('background')}; }}
.action-title {{ font-weight: 700; }}
.migration-note {{ padding-top: 8px; font-size: {max(8, round(font_size * 0.77))}px; }}

.shell-header {{ padding: 18px 22px 14px; background: {palette.color('surface')}; border-bottom: 2px solid {palette.color('accent')}; border-radius: 13px 13px 0 0; }}
.logo-frame {{ min-width: 52px; min-height: 46px; margin-right: 12px; }}
.shell-title {{ color: {palette.color('accent')}; font-size: {round(font_size * 1.45)}px; font-weight: 700; }}
.shell-subtitle, .page-subtitle, .sidebar-hint {{ color: {palette.color('muted')}; }}
.shell-clock {{ color: {palette.color('foreground')}; font-size: {round(font_size * 1.2)}px; padding-right: 16px; }}
.close-button {{ min-width: 34px; min-height: 34px; border-radius: 9px; background: {palette.color('surface')}; color: {palette.color('foreground')}; }}
.header-icon {{ min-width: 34px; min-height: 34px; margin-right: 7px; border-radius: 9px; background: {palette.color('surface')}; color: {palette.color('muted')}; font-size: {round(font_size * 1.2)}px; }}
.header-icon:hover {{ background: {palette.color('surface_alt')}; color: {palette.color('accent')}; }}
.header-icon.active {{ background: {palette.color('accent')}; color: {palette.color('background')}; }}
.header-weather {{ min-height: 34px; margin-right: 12px; padding: 0 10px; border-radius: 9px; background: {palette.color('surface')}; color: {palette.color('foreground')}; font-size: {round(font_size * 1.1)}px; font-weight: 700; }}
.header-weather:hover {{ background: {palette.color('surface_alt')}; color: {palette.color('accent')}; }}
.media-card {{ padding: 11px; background: {palette.color('background')}; border: 1px solid {palette.color('surface_alt')}; border-radius: 10px; }}
.media-icon {{ color: {palette.color('accent_alt')}; font-size: {round(font_size * 1.7)}px; min-width: 30px; }}
.media-title {{ color: {palette.color('foreground')}; font-weight: 700; }}
.media-artist {{ color: {palette.color('muted')}; }}
.media-button {{ min-width: 36px; min-height: 30px; border-radius: 8px; background: {palette.color('surface_alt')}; color: {palette.color('foreground')}; }}
.media-button:hover {{ background: {palette.color('accent_alt')}; color: {palette.color('background')}; }}
.media-button.primary {{ background: {palette.color('accent')}; color: {palette.color('background')}; }}
.close-button:hover {{ background: {palette.color('error')}; color: {palette.color('background')}; }}
.shell-separator, .sidebar-separator {{ background: {palette.color('surface_alt')}; min-height: 1px; }}
.shell-content {{ padding: 16px 20px 20px; }}
.page-scroll {{ min-height: 0; background: transparent; }}
.compact .shell-header {{ padding: 9px 12px; }}
.compact .shell-content {{ padding: 9px; }}
.compact .sidebar {{ min-width: 0; padding: 6px; }}
.compact .nav-item {{ padding: 8px; }}
.compact .nav-icon {{ min-width: 24px; }}
.compact .inspector {{ min-width: 0; }}
.compact .settings-card {{ min-width: 0; }}
.compact .metric-card {{ min-width: 0; }}
.compact .wallpaper-preview {{ min-width: 0; }}
.compact .page-subtitle {{ font-size: {max(10, font_size - 2)}px; }}
.sidebar {{ min-width: 190px; padding: 10px 14px 10px 10px; background: {palette.color('surface')}; border: 1px solid {palette.color('accent_alt')}; border-radius: 12px; }}
.sidebar-label {{ color: {palette.color('muted')}; font-size: {max(9, round(font_size * 0.72))}px; padding: 5px 8px; }}
.nav-item, .future-row {{ padding: 10px 12px; border-radius: 9px; color: {palette.color('foreground')}; }}
.nav-item {{ background: transparent; }}
.nav-item:hover {{ background: {palette.color('surface_alt')}; color: {palette.color('accent')}; }}
.nav-item.active {{ background: {palette.color('accent')}; color: {palette.color('background')}; }}
.nav-item.active:hover {{ background: {palette.color('accent')}; color: {palette.color('background')}; }}
.nav-icon {{ color: {palette.color('accent')}; min-width: 24px; }}
.future-row {{ color: {palette.color('muted')}; }}
.page-host, .page, .page-main {{ min-height: 0; }}
.page {{ padding-left: 2px; }}
.page-title {{ color: {palette.color('foreground')}; font-size: {round(font_size * 1.4)}px; font-weight: 700; }}
.section-title, .inspector-title {{ color: {palette.color('accent')}; font-weight: 700; padding-top: 4px; }}
.metric-card {{ min-width: 220px; padding: 13px 15px; background: {palette.color('surface')}; border: 1px solid {palette.color('surface_alt')}; border-radius: 11px; }}
.metric-card.tone-accent {{ border-top: 3px solid {palette.color('accent')}; }}
.metric-card.tone-alternate {{ border-top: 3px solid {palette.color('accent_alt')}; }}
.metric-card.tone-success {{ border-top: 3px solid {palette.color('success')}; }}
.metric-card.tone-warning {{ border-top: 3px solid {palette.color('warning')}; }}
.metric-icon, .status-icon, .quick-icon {{ color: {palette.color('accent_alt')}; font-size: {round(font_size * 1.25)}px; min-width: 28px; }}
.metric-label, .metric-detail, .status-detail {{ color: {palette.color('muted')}; }}
.metric-value {{ color: {palette.color('foreground')}; font-size: {round(font_size * 1.55)}px; font-weight: 700; }}
.status-list {{ padding: 4px; background: {palette.color('surface')}; border: 1px solid {palette.color('accent_alt')}; border-radius: 11px; }}
.status-row {{ padding: 9px 11px; border-radius: 8px; }}
.status-row:hover {{ background: {palette.color('surface_alt')}; }}
.status-title {{ color: {palette.color('foreground')}; font-weight: 700; }}
.status-value, .network-emphasis {{ color: {palette.color('accent')}; font-weight: 700; }}
.inspector {{ min-width: 340px; padding: 14px; background: {palette.color('surface')}; border: 1px solid {palette.color('accent')}; border-radius: 12px; }}
.inspector-scroll {{ min-height: 0; background: transparent; }}
.quick-card {{ padding: 12px; background: {palette.color('background')}; border: 1px solid {palette.color('accent_alt')}; border-radius: 10px; }}
.control-button, .primary-button, .secondary-button {{ padding: 8px 11px; border-radius: 8px; }}
.control-button, .secondary-button {{ background: {palette.color('surface_alt')}; color: {palette.color('foreground')}; }}
.primary-button {{ background: {palette.color('accent')}; color: {palette.color('background')}; font-weight: 700; }}
.control-button:hover, .secondary-button:hover {{ background: {palette.color('accent_alt')}; color: {palette.color('background')}; }}
.primary-button:hover {{ background: {palette.color('accent_alt')}; }}
.device-list {{ padding-top: 4px; }}
.device-row {{ padding: 11px 13px; background: {palette.color('surface')}; border: 1px solid {palette.color('surface_alt')}; border-radius: 10px; }}
.device-row:hover {{ background: {palette.color('surface_alt')}; }}
.device-icon, .feature-icon {{ color: {palette.color('accent_alt')}; font-size: 18px; min-width: 30px; }}
.connected-pill {{ padding: 4px 7px; border-radius: 7px; background: {palette.color('accent')}; color: {palette.color('background')}; font-weight: 700; }}
.weather-current {{ border: 1px solid {palette.color('accent')}; }}
.weather-day {{ padding: 10px 6px; background: {palette.color('surface')}; border-radius: 10px; color: {palette.color('foreground')}; }}
.weather-location-remove {{ min-width: 22px; min-height: 22px; padding: 0; border-radius: 6px; background: {palette.color('surface_alt')}; color: {palette.color('muted')}; font-weight: 700; }}
.weather-location-remove:hover {{ background: {palette.color('error')}; color: {palette.color('background')}; }}
.feature-card {{ padding: 20px; background: {palette.color('surface')}; border: 1px solid {palette.color('success')}; border-radius: 12px; }}
.feature-icon {{ font-size: 42px; }}
.feature-list {{ color: {palette.color('foreground')}; font-size: 15px; }}
.action-row {{ padding: 10px 12px; background: {palette.color('surface')}; border: 1px solid {palette.color('surface_alt')}; border-radius: 10px; color: {palette.color('foreground')}; }}
.action-row:hover {{ background: {palette.color('surface_alt')}; }}
.action-arrow {{ color: {palette.color('accent')}; font-size: 22px; }}
.danger-button {{ padding: 8px 11px; border-radius: 8px; background: {palette.color('error')}; color: {palette.color('background')}; font-weight: 700; }}
.danger-button:hover {{ background: {palette.color('accent_alt')}; }}
.confirm-card {{ padding: 12px; background: {palette.color('background')}; border: 1px solid {palette.color('error')}; border-radius: 10px; }}
.ethernet-card {{ padding: 12px 14px; background: {palette.color('surface')}; border: 1px solid {palette.color('accent')}; border-radius: 11px; }}
.rate-value, .address-label {{ color: {palette.color('foreground')}; font-weight: 700; }}
.mini-button {{ padding: 4px 7px; border-radius: 6px; background: {palette.color('surface_alt')}; color: {palette.color('foreground')}; font-size: {max(9, round(font_size * 0.72))}px; }}
.mini-button:hover {{ background: {palette.color('accent_alt')}; color: {palette.color('background')}; }}
.font-size-card {{ padding: 12px; background: {palette.color('background')}; border: 1px solid {palette.color('surface_alt')}; border-radius: 10px; }}
.font-size-value {{ color: {palette.color('accent')}; font-size: {round(font_size * 1.4)}px; font-weight: 700; }}
.font-size-grid {{ padding-top: 3px; }}
.size-button {{ padding: 8px 11px; border-radius: 7px; background: {palette.color('surface_alt')}; color: {palette.color('foreground')}; border: 1px solid {palette.color('surface_alt')}; font-weight: 700; }}
.size-button:hover {{ background: {palette.color('accent_alt')}; color: {palette.color('background')}; }}
.size-button-selected {{ padding: 8px 11px; border-radius: 7px; background: {palette.color('accent')}; color: {palette.color('background')}; border: 2px solid {palette.color('accent_alt')}; font-weight: 700; }}
.size-button-selected:hover {{ background: {palette.color('accent_alt')}; color: {palette.color('background')}; }}
.hyprland-page {{ padding: 18px; background: {palette.color('surface')}; border: 1px solid {palette.color('surface_alt')}; border-radius: 12px; }}
.settings-row {{ min-height: 112px; }}
.settings-card {{ min-width: 420px; padding: 15px; background: {palette.color('background')}; border: 1px solid {palette.color('surface_alt')}; border-radius: 10px; }}
.settings-card.tone-accent {{ border-left: 4px solid {palette.color('accent')}; }}
.settings-card.tone-alternate {{ border-left: 4px solid {palette.color('accent_alt')}; }}
.settings-card.tone-success {{ border-left: 4px solid {palette.color('success')}; }}
.settings-card.tone-warning {{ border-left: 4px solid {palette.color('warning')}; }}
.window-effects-card {{ min-height: 140px; }}
.choice-button {{ padding: 8px 10px; border-radius: 8px; background: {palette.color('surface_alt')}; color: {palette.color('foreground')}; border: 1px solid {palette.color('accent')}; font-weight: 700; }}
.choice-button:hover, .choice-button:focus {{ background: {palette.color('accent')}; color: {palette.color('background')}; }}
.choice-button-selected {{ padding: 8px 10px; border-radius: 8px; background: {palette.color('accent_alt')}; color: {palette.color('background')}; border: 3px solid {palette.color('accent')}; box-shadow: inset 0 0 0 1px {palette.color('background')}; font-weight: 700; }}
.choice-button-selected:hover {{ background: {palette.color('accent')}; color: {palette.color('background')}; }}
.waybar-card {{ padding: 12px; background: {palette.color('background')}; border: 1px solid {palette.color('surface_alt')}; border-radius: 10px; }}
.wallpaper-scroll {{ min-height: 0; background: transparent; }}
.wallpaper-row {{ padding: 9px; background: {palette.color('surface')}; border: 1px solid {palette.color('surface_alt')}; border-radius: 10px; }}
.wallpaper-row:hover {{ border-color: {palette.color('accent')}; }}
.wallpaper-preview {{ border-radius: 8px; }}
.empty-state {{ padding: 20px; color: {palette.color('muted')}; background: {palette.color('surface')}; border-radius: 10px; }}
.calculator-card {{ padding: 18px; background: {palette.color('surface')}; border: 1px solid {palette.color('surface_alt')}; border-radius: 12px; }}
.calculator-input {{ padding: 12px; background: {palette.color('background')}; color: {palette.color('foreground')}; border: 1px solid {palette.color('accent')}; border-radius: 9px; }}
.calculator-result {{ padding: 16px; color: {palette.color('accent')}; background: {palette.color('background')}; border-radius: 9px; font-size: {round(font_size * 1.8)}px; font-weight: 700; }}
.manual-card {{ padding: 10px; background: {palette.color('background')}; border: 1px solid {palette.color('surface_alt')}; border-radius: 9px; }}
.manual-title {{ color: {palette.color('foreground')}; font-weight: 700; }}
.manual-code {{ color: {palette.color('accent')}; font-weight: 700; }}
.application-scroll {{ min-height: 0; background: transparent; }}
.application-row {{ padding: 10px 12px; background: {palette.color('surface')}; border: 1px solid {palette.color('surface_alt')}; border-radius: 9px; color: {palette.color('foreground')}; }}
.application-row:hover {{ background: {palette.color('surface_alt')}; border-color: {palette.color('accent')}; }}
.application-icon {{ color: {palette.color('accent_alt')}; font-size: {round(font_size * 1.5)}px; min-width: 30px; }}
.layout-selector {{ padding: 7px 9px; border-radius: 7px; background: {palette.color('surface_alt')}; color: {palette.color('foreground')}; }}
.layout-selector:hover {{ background: {palette.color('accent_alt')}; color: {palette.color('background')}; }}
.layout-options {{ padding: 5px; background: {palette.color('surface')}; border: 1px solid {palette.color('surface_alt')}; border-radius: 8px; }}
.layout-option {{ padding: 5px 7px; border-radius: 6px; color: {palette.color('foreground')}; }}
.layout-option:hover {{ background: {palette.color('surface_alt')}; }}
.layout-option-selected {{ padding: 5px 7px; border-radius: 6px; background: {palette.color('accent')}; color: {palette.color('background')}; font-weight: 700; }}
.layout-option-selected:hover {{ background: {palette.color('accent_alt')}; color: {palette.color('background')}; }}
"""


def render_hyprlock(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    date_offset = font_size * 9 + 76
    weather_offset = date_offset + round(font_size * 2.25) + 24
    def label(text: str, size: int, role: str, position: str, halign: str = "center", valign: str = "center") -> str:
        return f"""label {{
    monitor =
    text = {text}
    font_size = {size}
    font_family = {font_family}
    color = rgb({palette.bare(role)})
    position = {position}
    halign = {halign}
    valign = {valign}
}}
"""

    return f"""general {{
    hide_cursor = true
}}

background {{
    monitor =
    path = /var/lib/spectrumos/appearance/current.png
    blur_passes = 2
    blur_size = 5
    brightness = 0.55
    color = rgb({palette.bare("background")})
}}

image {{
    monitor =
    path = /var/lib/spectrumos/appearance/lock-branding.png
    size = 378
    border_size = 0
    border_color = rgba(00000000)
    rounding = 0
    shadow_passes = 0
    position = 0, 18%
    halign = center
    valign = center
}}

image {{
    monitor =
    path = /var/lib/spectrumos/appearance/$USER.png
    size = 104
    border_size = 0
    rounding = -1
    shadow_passes = 0
    position = 0, -10%
    halign = center
    valign = center
}}

{label("$TIME", font_size * 6, "foreground", "4%, -64", "left", "top")}
{label('cmd[update:60000] date +"%A, %B %d"', round(font_size * 1.5), "foreground", f"4%, -{date_offset}", "left", "top")}
{label("cmd[update:60000] /usr/lib/spectrumos/weather-adapter --lockscreen", round(font_size * 1.5), "foreground", f"4%, -{weather_offset}", "left", "top")}
{label("$USER", round(font_size * 1.5), "foreground", "0, -23%")}
input-field {{
    monitor =
    size = 360, 60
    outline_thickness = 2
    inner_color = rgb({palette.bare("surface")})
    outer_color = rgb({palette.bare("accent")})
    check_color = rgb({palette.bare("success")})
    fail_color = rgb({palette.bare("error")})
    capslock_color = rgb({palette.bare("warning")})
    font_color = rgb({palette.bare("foreground")})
    font_family = {font_family}
    fade_on_empty = false
    placeholder_text = Enter your password
    check_text = Unlocking…
    fail_text = Password not recognized. Try again.
    rounding = 16
    position = 0, -32%
    halign = center
    valign = center
}}

{label("Press Enter to unlock", font_size, "foreground", "0, -40%")}
{label("󰌾  Session locked", font_size, "foreground", "4%, 36", "left", "bottom")}
{label("Keyboard: $LAYOUT", font_size, "foreground", "-4%, 36", "right", "bottom")}
"""


def render_gtk(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return f"""@define-color theme_bg_color {palette.color('background')};
@define-color theme_fg_color {palette.color('foreground')};
@define-color theme_base_color {palette.color('surface')};
@define-color theme_text_color {palette.color('foreground')};
@define-color theme_selected_bg_color {palette.color('accent')};
@define-color theme_selected_fg_color {palette.color('background')};
@define-color insensitive_bg_color {palette.color('surface_alt')};
@define-color insensitive_fg_color {palette.color('muted')};
@define-color borders {palette.color('surface_alt')};
@define-color warning_color {palette.color('warning')};
@define-color error_color {palette.color('error')};
@define-color success_color {palette.color('success')};
@define-color accent_color {palette.color('accent')};
@define-color accent_bg_color {palette.color('accent')};
@define-color accent_fg_color {palette.color('background')};
@define-color destructive_color {palette.color('error')};
@define-color destructive_bg_color {palette.color('error')};
@define-color destructive_fg_color {palette.color('background')};
@define-color success_bg_color {palette.color('success')};
@define-color success_fg_color {palette.color('background')};
@define-color warning_bg_color {palette.color('warning')};
@define-color warning_fg_color {palette.color('background')};
@define-color error_bg_color {palette.color('error')};
@define-color error_fg_color {palette.color('background')};
@define-color window_bg_color {palette.color('background')};
@define-color window_fg_color {palette.color('foreground')};
@define-color view_bg_color {palette.color('surface')};
@define-color view_fg_color {palette.color('foreground')};
@define-color headerbar_bg_color {palette.color('surface')};
@define-color headerbar_fg_color {palette.color('foreground')};
@define-color card_bg_color {palette.color('surface')};
@define-color card_fg_color {palette.color('foreground')};
@define-color dialog_bg_color {palette.color('background')};
@define-color dialog_fg_color {palette.color('foreground')};
@define-color popover_bg_color {palette.color('surface')};
@define-color popover_fg_color {palette.color('foreground')};
@define-color shade_color {palette.color('surface_alt')};

* {{
    font-size: {font_size}px;
}}

window.csd decoration,
window.solid-csd decoration {{
    box-shadow: none;
    margin: 0;
    background-image: none;
}}

window,
dialog,
popover,
.popover,
.osd,
.background > box,
window > box,
dialog > box,
.background {{
    background-color: @theme_bg_color;
    color: @theme_fg_color;
}}

headerbar,
toolbar,
.titlebar,
notebook > header,
menubar,
menu,
pathbar,
.path-bar {{
    background-color: @theme_base_color;
    background-image: none;
    color: @theme_fg_color;
    border-color: @borders;
}}

button,
entry,
spinbutton,
combobox,
dropdown,
searchbar,
searchentry {{
    background-color: @theme_base_color;
    background-image: none;
    color: @theme_fg_color;
    border-color: @borders;
    border-radius: 7px;
}}

button:hover,
row:hover {{
    background-color: @insensitive_bg_color;
}}

.view,
iconview,
view,
textview,
treeview,
notebook > stack,
list,
listview,
columnview,
gridview,
placessidebar,
placessidebar row,
filechooser,
filechooserwidget,
filechooserwidget box,
filechooser box,
filechooser headerbar,
filechooser .titlebar,
filechooser .dialog-action-area,
filechooser .dialog-action-box,
placessidebar viewport,
scrolledwindow > viewport {{
    background-color: @theme_base_color;
    background-image: none;
    color: @theme_text_color;
}}

button:checked,
button.suggested-action,
selection,
*:selected,
*:selected:backdrop,
*:selected:not(:focus) {{
    background-color: @theme_selected_bg_color;
    color: @theme_selected_fg_color;
}}

tooltip {{
    background-color: @theme_base_color;
    color: @theme_fg_color;
    border: 1px solid @theme_selected_bg_color;
}}

label,
button label,
entry,
text {{ color: @theme_fg_color; }}

button:checked label,
button.suggested-action label,
*:selected label,
*:selected:backdrop label,
*:selected:not(:focus) label {{ color: @theme_selected_fg_color; }}

separator {{ background-color: @borders; }}

scrollbar slider {{
    background-color: @insensitive_bg_color;
    border-radius: 999px;
}}

scrollbar slider:hover {{ background-color: @theme_selected_bg_color; }}

:disabled {{
    color: @insensitive_fg_color;
}}

.error {{ color: @error_color; }}
.warning {{ color: @warning_color; }}
.success {{ color: @success_color; }}
"""


def _render_folder_icon(palette: Palette, role: str) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <path d="M5 15a6 6 0 0 1 6-6h15l7 7h20a6 6 0 0 1 6 6v29a6 6 0 0 1-6 6H11a6 6 0 0 1-6-6z" fill="{palette.color('surface_alt')}" stroke="{palette.color(role)}" stroke-width="3"/>
  <path d="M7 27h50v24a4 4 0 0 1-4 4H11a4 4 0 0 1-4-4z" fill="{palette.color(role)}"/>
  <path d="M18 39h28" stroke="{palette.color('background')}" stroke-width="4" stroke-linecap="round" opacity=".72"/>
</svg>
"""


def render_folder(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return _render_folder_icon(palette, "accent")


def render_folder_documents(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return _render_folder_icon(palette, "accent_alt")


def render_folder_downloads(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return _render_folder_icon(palette, "accent")


def render_folder_music(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return _render_folder_icon(palette, "accent_alt")


def render_folder_pictures(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return _render_folder_icon(palette, "accent")


def render_folder_videos(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return _render_folder_icon(palette, "muted")


def render_user_home(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return _render_folder_icon(palette, "muted")


def render_kvantum(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return f"""[%General]
author=SpectrumOS
comment=Generated from the active Spectrum semantic palette
respect_DE=true
composite=false
no_window_pattern=true
translucent_windows=false
reduce_window_opacity=0
animate_states=true
group_toolbar_buttons=false
joined_inactive_tabs=true
scroll_width=12
slider_width=8
slider_handle_width=16
slider_handle_length=16
layout_spacing=4
layout_margin=6
small_icon_size=16
button_icon_size=16
toolbar_icon_size=font
tooltip_shadow_depth=0
menu_shadow_depth=0

[GeneralColors]
window.color={palette.color('background')}
inactive.window.color={palette.color('background')}
base.color={palette.color('surface')}
inactive.base.color={palette.color('surface')}
alt.base.color={palette.color('surface_alt')}
inactive.alt.base.color={palette.color('surface_alt')}
button.color={palette.color('surface')}
light.color={palette.color('surface_alt')}
mid.light.color={palette.color('surface_alt')}
dark.color={palette.color('background')}
mid.color={palette.color('surface_alt')}
highlight.color={palette.color('accent')}
inactive.highlight.color={palette.color('accent_alt')}
text.color={palette.color('foreground')}
window.text.color={palette.color('foreground')}
button.text.color={palette.color('foreground')}
disabled.text.color={palette.color('muted')}
tooltip.base.color={palette.color('surface')}
tooltip.text.color={palette.color('foreground')}
link.color={palette.color('accent')}
visited.link.color={palette.color('accent_alt')}

[PanelButtonCommand]
frame.element=button
frame.top={KVANTUM_BUTTON_RADIUS}
frame.bottom={KVANTUM_BUTTON_RADIUS}
frame.left={KVANTUM_BUTTON_RADIUS}
frame.right={KVANTUM_BUTTON_RADIUS}

[LineEdit]
inherits=PanelButtonCommand
frame.element=button

[ComboBox]
inherits=PanelButtonCommand
frame.element=button

[CheckBox]
inherits=PanelButtonCommand
indicator.size={KVANTUM_INDICATOR_SIZE}

[RadioButton]
inherits=PanelButtonCommand
indicator.size={KVANTUM_INDICATOR_SIZE}

[ToolTip]
frame.element=tooltip
frame.top={KVANTUM_TOOLTIP_RADIUS}
frame.bottom={KVANTUM_TOOLTIP_RADIUS}
frame.left={KVANTUM_TOOLTIP_RADIUS}
frame.right={KVANTUM_TOOLTIP_RADIUS}

[Focus]
frame.element=focus
frame.top=2
frame.bottom=2
frame.left=2
frame.right=2

[Hacks]
respect_darkness={'true' if palette.variant == 'dark' else 'false'}
normal_default_pushbutton=true
transparent_arrow_button=true
"""


def render_qt_colors(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    return f"""[ColorEffects:Disabled]
Color={palette.color('muted')}
ColorAmount=0
ColorEffect=0
ContrastAmount=0.35
ContrastEffect=1
IntensityAmount=0
IntensityEffect=0

[Colors:Button]
BackgroundAlternate={palette.color('surface_alt')}
BackgroundNormal={palette.color('surface')}
DecorationFocus={palette.color('accent')}
DecorationHover={palette.color('accent_alt')}
ForegroundActive={palette.color('accent')}
ForegroundInactive={palette.color('muted')}
ForegroundLink={palette.color('accent')}
ForegroundNegative={palette.color('error')}
ForegroundNeutral={palette.color('warning')}
ForegroundNormal={palette.color('foreground')}
ForegroundPositive={palette.color('success')}
ForegroundVisited={palette.color('accent_alt')}

[Colors:Selection]
BackgroundAlternate={palette.color('accent_alt')}
BackgroundNormal={palette.color('accent')}
DecorationFocus={palette.color('accent')}
DecorationHover={palette.color('accent_alt')}
ForegroundNormal={palette.color('background')}

[Colors:Tooltip]
BackgroundNormal={palette.color('surface')}
DecorationFocus={palette.color('accent')}
DecorationHover={palette.color('accent_alt')}
ForegroundNormal={palette.color('foreground')}

[Colors:View]
BackgroundAlternate={palette.color('surface_alt')}
BackgroundNormal={palette.color('surface')}
DecorationFocus={palette.color('accent')}
DecorationHover={palette.color('accent_alt')}
ForegroundActive={palette.color('accent')}
ForegroundInactive={palette.color('muted')}
ForegroundLink={palette.color('accent')}
ForegroundNegative={palette.color('error')}
ForegroundNeutral={palette.color('warning')}
ForegroundNormal={palette.color('foreground')}
ForegroundPositive={palette.color('success')}
ForegroundVisited={palette.color('accent_alt')}

[Colors:Window]
BackgroundAlternate={palette.color('surface_alt')}
BackgroundNormal={palette.color('background')}
DecorationFocus={palette.color('accent')}
DecorationHover={palette.color('accent_alt')}
ForegroundActive={palette.color('accent')}
ForegroundInactive={palette.color('muted')}
ForegroundLink={palette.color('accent')}
ForegroundNegative={palette.color('error')}
ForegroundNeutral={palette.color('warning')}
ForegroundNormal={palette.color('foreground')}
ForegroundPositive={palette.color('success')}
ForegroundVisited={palette.color('accent_alt')}

[General]
ColorScheme=Spectrum
Name=Spectrum
shadeSortColumn=true
"""


def _kvantum_corner_paths(radius: int) -> dict[str, str]:
    r = radius
    return {
        "topleft": f"M 0,{r} A {r},{r} 0 0 1 {r},0 L {r},{r} Z",
        "topright": f"M {r},{r} A {r},{r} 0 0 0 0,0 L 0,{r} Z",
        "bottomleft": f"M 0,0 A {r},{r} 0 0 0 {r},{r} L {r},0 Z",
        "bottomright": f"M {r},0 A {r},{r} 0 0 1 0,{r} L 0,0 Z",
    }


def _kvantum_frame_pieces(
    element_id: str, x: int, y: int, size: int, radius: int, fill: str, stroke: str | None = None
) -> list[str]:
    """Render the four corner arcs and four edge strips Kvantum reads as a real
    frame.top/bottom/left/right nine-patch, instead of a single <rect rx> that
    Kvantum has no frame data for and falls back to stretching as a near-circle."""
    stroke_attr = f' stroke="{stroke}"' if stroke else ""
    edge = size - 2 * radius
    pieces = []
    for name, path in _kvantum_corner_paths(radius).items():
        px = x if "left" in name else x + size - radius
        py = y if "top" in name else y + size - radius
        pieces.append(f'<path id="{element_id}-{name}" d="{path}" transform="translate({px},{py})" fill="{fill}"{stroke_attr}/>')
    edges = {
        "top": (x + radius, y, edge, radius),
        "bottom": (x + radius, y + size - radius, edge, radius),
        "left": (x, y + radius, radius, edge),
        "right": (x + size - radius, y + radius, radius, edge),
    }
    for name, (ex, ey, ew, eh) in edges.items():
        pieces.append(f'<rect id="{element_id}-{name}" x="{ex}" y="{ey}" width="{ew}" height="{eh}" fill="{fill}"{stroke_attr}/>')
    return pieces


def _kvantum_nine_patch(
    element_id: str, x: int, y: int, size: int, radius: int, fill: str, stroke: str | None = None
) -> str:
    stroke_attr = f' stroke="{stroke}"' if stroke else ""
    center = f'<rect id="{element_id}" x="{x}" y="{y}" width="{size}" height="{size}" fill="{fill}"{stroke_attr}/>'
    pieces = [center, *_kvantum_frame_pieces(element_id, x, y, size, radius, fill, stroke)]
    return "\n  ".join(pieces)


def render_kvantum_svg(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    r = KVANTUM_BUTTON_RADIUS
    t = KVANTUM_TOOLTIP_RADIUS
    button_size = 4 * r
    tooltip_size = 4 * t
    indicator = KVANTUM_INDICATOR_SIZE

    buttons = "\n  ".join(
        _kvantum_nine_patch(f"button-{state}", x, y, button_size, r, fill, stroke)
        for state, x, y, fill, stroke in (
            ("normal", 0, 0, palette.color("surface"), palette.color("surface_alt")),
            ("focused", button_size, 0, palette.color("surface_alt"), palette.color("accent")),
            ("pressed", 0, button_size, palette.color("accent"), None),
            ("toggled", button_size, button_size, palette.color("accent"), None),
        )
    )
    tooltip = _kvantum_nine_patch(
        "tooltip-normal", 2 * button_size, 0, tooltip_size, t, palette.color("surface"), palette.color("accent")
    )
    focus = "\n  ".join(
        _kvantum_frame_pieces(
            "focus", 2 * button_size, tooltip_size, button_size, 2, "none", palette.color("accent")
        )
    )
    indicators = "\n  ".join(
        (
            f'<rect id="checkbox-normal" x="0" y="{2 * button_size}" width="{indicator}" height="{indicator}" '
            f'rx="3" fill="{palette.color("surface")}" stroke="{palette.color("muted")}"/>',
            f'<rect id="checkbox-focused" x="{indicator + 4}" y="{2 * button_size}" width="{indicator}" height="{indicator}" '
            f'rx="3" fill="{palette.color("surface")}" stroke="{palette.color("accent")}"/>',
            f'<rect id="checkbox-checked-normal" x="{2 * (indicator + 4)}" y="{2 * button_size}" width="{indicator}" height="{indicator}" '
            f'rx="3" fill="{palette.color("accent")}"/>',
            f'<rect id="radio-normal" x="0" y="{2 * button_size + indicator + 4}" width="{indicator}" height="{indicator}" '
            f'rx="{indicator // 2}" fill="{palette.color("surface")}" stroke="{palette.color("muted")}"/>',
            f'<rect id="radio-focused" x="{indicator + 4}" y="{2 * button_size + indicator + 4}" width="{indicator}" height="{indicator}" '
            f'rx="{indicator // 2}" fill="{palette.color("surface")}" stroke="{palette.color("accent")}"/>',
            f'<rect id="radio-checked-normal" x="{2 * (indicator + 4)}" y="{2 * button_size + indicator + 4}" width="{indicator}" height="{indicator}" '
            f'rx="{indicator // 2}" fill="{palette.color("accent")}"/>',
        )
    )

    canvas_width = max(3 * button_size, 2 * (indicator + 4) + indicator)
    canvas_height = 2 * button_size + 2 * (indicator + 4)
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{canvas_width}" height="{canvas_height}" viewBox="0 0 {canvas_width} {canvas_height}">
  <rect id="window-normal" x="0" y="0" width="{button_size}" height="{button_size}" fill="{palette.color('background')}"/>
  {buttons}
  {tooltip}
  {focus}
  {indicators}
</svg>
"""


def render_telegram_theme(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    roles = {
        "windowBg": palette.color("background"),
        "windowFg": palette.color("foreground"),
        "windowBgOver": palette.color("surface_alt"),
        "windowSubTextFg": palette.color("muted"),
        "windowBoldFg": palette.color("foreground"),
        "windowBgActive": palette.color("accent"),
        "windowFgActive": palette.color("background"),
        "windowActiveTextFg": palette.color("accent"),
        "activeButtonBg": palette.color("accent"),
        "activeButtonFg": palette.color("background"),
        "menuBg": palette.color("surface"),
        "menuBgOver": palette.color("surface_alt"),
        "menuFg": palette.color("foreground"),
        "menuFgDisabled": palette.color("muted"),
        "dialogsBg": palette.color("background"),
        "dialogsNameFg": palette.color("foreground"),
        "dialogsTextFg": palette.color("muted"),
        "dialogsBgActive": palette.color("accent"),
        "dialogsNameFgActive": palette.color("background"),
        "dialogsTextFgActive": palette.color("background"),
        "historyTextInFg": palette.color("foreground"),
        "historyTextOutFg": palette.color("foreground"),
        "msgInBg": palette.color("surface"),
        "msgOutBg": palette.color("surface_alt"),
        "msgInServiceFg": palette.color("accent"),
        "msgOutServiceFg": palette.color("accent_alt"),
        "historyLinkInFg": palette.color("accent"),
        "historyLinkOutFg": palette.color("accent_alt"),
    }
    return "// Generated by SpectrumOS. Import this file from Telegram Desktop Settings.\n" + "".join(
        f"{name}: {value};\n" for name, value in roles.items()
    )


def render_vencord_theme(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    # Discord's own "Custom Theme" builder was removed from the client; Vencord's QuickCSS
    # (loaded automatically, no manual paste step) is the mechanism that actually works, so
    # it overrides Discord's own theming custom properties directly.
    roles = {
        "--background-primary": palette.color("background"),
        "--background-secondary": palette.color("surface"),
        "--background-secondary-alt": palette.color("surface_alt"),
        "--background-tertiary": palette.color("background"),
        "--background-floating": palette.color("surface"),
        "--text-normal": palette.color("foreground"),
        "--text-muted": palette.color("muted"),
        "--header-primary": palette.color("foreground"),
        "--header-secondary": palette.color("muted"),
        "--interactive-normal": palette.color("muted"),
        "--interactive-hover": palette.color("foreground"),
        "--interactive-active": palette.color("accent"),
        "--brand-experiment": palette.color("accent"),
        "--brand-500": palette.color("accent"),
        "--status-positive": palette.color("success"),
        "--status-warning": palette.color("warning"),
        "--status-danger": palette.color("error"),
    }
    body = "".join(f"  {name}: {value};\n" for name, value in roles.items())
    return (
        "/* Generated by SpectrumOS. Paste into Vencord Settings > QuickCSS. */\n"
        f":root {{\n{body}}}\n"
    )


def render_zen_browser_theme(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    # Confirmed by reading Zen's own bundled zen-theme.css and zenThemeModifier.js (from
    # omni.ja) rather than guessing a second time:
    # 1. Zen's whole --zen-colors-primary/-secondary/-tertiary/-border ramp is *computed*
    #    from one input, --zen-primary-color, via Zen's own color-mix()/light-dark()
    #    formulas -- overriding that one input and letting Zen's own math produce the ramp
    #    keeps it internally consistent and survives Zen's own formula changes better than
    #    hand-picking every derived shade ourselves (the previous approach).
    # 2. zen-theme.css sets --zen-colors-primary (and friends) on the same `:root` selector
    #    our own userChrome.css rule uses -- a specificity tie, decided only by whichever
    #    stylesheet happens to load second. `!important` on every declaration here removes
    #    that guesswork regardless of load order.
    # 3. The browser's actual visible chrome/window background is painted from *several*
    #    separate variables, each hardcoded by Zen to a flat gray/near-black light/dark
    #    pair with no reference to --zen-primary-color or the branding variables at all --
    #    previously untouched here, which is why overriding accent colors alone left the
    #    window looking completely unthemed. --zen-main-browser-background paints the main
    #    background layer; --zen-themed-toolbar-bg-transparent (its dark-mode branch is a
    #    bare literal, not derived from --zen-branding-bg at all despite the name) paints
    #    #zen-main-app-wrapper, another large structural surface.
    # 4. Zen conditionally re-declares --zen-primary-color (and others) at higher
    #    specificity for window states like `:root[zen-unsynced-window="true"]` (no linked
    #    Zen account -- the common case for a fresh profile), which would beat a plain
    #    `:root` rule even with !important, since among tied !important declarations
    #    specificity is compared before source order. `:root:root:root` -- a well-known
    #    userChrome.css technique -- outweighs any single- or double-attribute selector
    #    Zen might apply, without having to enumerate every state Zen could set.
    roles = {
        "--zen-primary-color": palette.color("accent"),
        "--zen-branding-dark": palette.color("background"),
        "--zen-branding-paper": palette.color("background"),
        "--zen-main-browser-background": palette.color("background"),
        "--zen-main-browser-background-toolbar": palette.color("background"),
        "--zen-themed-toolbar-bg-transparent": palette.color("background"),
        # Firefox's own long-standing Lightweight Theme variables -- stable across Firefox
        # releases for years and inherited by any Firefox-fork toolkit code, so these are
        # the reliable baseline regardless of Zen's own theming internals.
        "--lwt-accent-color": palette.color("background"),
        "--lwt-text-color": palette.color("foreground"),
        "--lwt-toolbar-field-background-color": palette.color("surface"),
        "--lwt-toolbar-field-color": palette.color("foreground"),
        "--toolbar-bgcolor": palette.color("surface"),
        "--toolbar-color": palette.color("foreground"),
        "--tab-selected-bgcolor": palette.color("surface_alt"),
    }
    body = "".join(f"  {name}: {value} !important;\n" for name, value in roles.items())
    return f":root:root:root {{\n{body}}}\n"


ZEN_EXTENSION_ID = "spectrumos-theme@spectrumos.dev"


def render_zen_extension_manifest(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    # A static WebExtension "theme" manifest -- sideloaded as a real add-on (an .xpi dropped
    # into the profile's own extensions/ directory, the same mechanism used to deploy
    # managed/enterprise extensions) rather than only via userChrome.css. Confirmed by
    # reading Zen's own LightweightThemeConsumer.sys.mjs: when an actual theme add-on is
    # active, Firefox/Zen's official theme pipeline inline-sets every --lwt-* variable
    # itself (and Zen's own zen-colors-* ramp derives from --lwt-accent-color when a real
    # theme exists) -- going through that pipeline sidesteps needing to out-specificity
    # Zen's own internal CSS entirely, rather than fighting its cascade from a stylesheet.
    colors = {
        "frame": palette.color("background"),
        "frame_inactive": palette.color("background"),
        "tab_background_text": palette.color("muted"),
        "tab_selected": palette.color("surface_alt"),
        "tab_text": palette.color("foreground"),
        "tab_line": palette.color("accent"),
        "toolbar": palette.color("surface"),
        "toolbar_text": palette.color("foreground"),
        "toolbar_field": palette.color("surface"),
        "toolbar_field_text": palette.color("foreground"),
        "toolbar_field_border": palette.color("surface_alt"),
        "sidebar": palette.color("background"),
        "sidebar_text": palette.color("foreground"),
        "sidebar_border": palette.color("surface_alt"),
        "sidebar_highlight": palette.color("accent"),
        "sidebar_highlight_text": palette.color("background"),
        "popup": palette.color("surface"),
        "popup_text": palette.color("foreground"),
        "popup_border": palette.color("surface_alt"),
        "icons": palette.color("foreground"),
        "button_background_active": palette.color("accent"),
        "button_background_hover": palette.color("surface_alt"),
        "ntp_background": palette.color("background"),
        "ntp_text": palette.color("foreground"),
    }
    manifest = {
        "manifest_version": 2,
        "name": "SpectrumOS Theme",
        "version": "1.0",
        "description": "Generated automatically from the active SpectrumOS wallpaper palette.",
        "browser_specific_settings": {"gecko": {"id": ZEN_EXTENSION_ID}},
        "theme": {"colors": colors},
    }
    return json.dumps(manifest, indent=2, sort_keys=True) + "\n"


def render_palette_json(palette: Palette, font_size: int = 13, font_family: str = DEFAULT_FONT_FAMILY) -> str:
    payload = {
        "schema_version": 1,
        "name": palette.name,
        "variant": palette.variant,
        "source": palette.source,
        "roles": palette.roles,
    }
    return json.dumps(payload, indent=2, sort_keys=True) + "\n"


RENDERERS = {
    "hyprland.lua": render_hyprland,
    "hyprlock.conf": render_hyprlock,
    "kitty.conf": render_kitty,
    "cava.theme": render_cava,
    "alacritty.toml": render_alacritty,
    "colors/spectrum.lua": render_neovim,
    "gtk-3.css": render_gtk,
    "gtk-4.css": render_gtk,
    "Spectrum-folder.svg": render_folder,
    "Spectrum-folder-documents.svg": render_folder_documents,
    "Spectrum-folder-downloads.svg": render_folder_downloads,
    "Spectrum-folder-music.svg": render_folder_music,
    "Spectrum-folder-pictures.svg": render_folder_pictures,
    "Spectrum-folder-videos.svg": render_folder_videos,
    "Spectrum-user-home.svg": render_user_home,
    "Spectrum.kvconfig": render_kvantum,
    "Spectrum.colors": render_qt_colors,
    "Spectrum.svg": render_kvantum_svg,
    "integrations/spectrum.tdesktop-theme": render_telegram_theme,
    "integrations/vencord-quickcss.css": render_vencord_theme,
    "integrations/zen-browser.css": render_zen_browser_theme,
    "integrations/zen-extension-manifest.json": render_zen_extension_manifest,
    "palette.json": render_palette_json,
}

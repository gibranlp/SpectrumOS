import json
import re
import unittest

from spectrum_theme.palette import Palette
from spectrum_theme.renderers import (
    KVANTUM_BUTTON_RADIUS,
    KVANTUM_INDICATOR_SIZE,
    KVANTUM_TOOLTIP_RADIUS,
    render_alacritty,
    render_cava,
    render_dunst,
    render_dunst_volume_icon,
    render_vencord_theme,
    render_eww,
    render_folder,
    render_folder_downloads,
    render_gtk,
    render_hyprlock,
    render_kitty,
    render_kvantum,
    render_qt_colors,
    render_kvantum_svg,
    render_neovim,
    render_telegram_theme,
    render_waybar_spectrum,
    render_waybar_spectrum_prism,
    render_waybar_spectrum_tonal,
    render_waybar_square,
    render_wofi,
    render_wofi_wallpaper,
    render_zen_browser_theme,
    render_zen_extension_manifest,
)


PALETTE = Palette(
    name="Renderer test",
    variant="dark",
    source="test",
    roles={
        "background": "#101218",
        "surface": "#191c24",
        "surface_alt": "#252a35",
        "foreground": "#e9edf5",
        "muted": "#9ca6b8",
        "accent": "#76b7ff",
        "accent_alt": "#c49aff",
        "success": "#78dba9",
        "warning": "#f2c66d",
        "error": "#ff8c9a",
    },
)


class RendererTests(unittest.TestCase):
    def test_cava_theme_uses_system_palette(self):
        rendered = render_cava(PALETTE)
        self.assertIn("background = '#101218'", rendered)
        self.assertIn("gradient_color_1 = '#76b7ff'", rendered)
        self.assertIn("gradient_color_2 = '#c49aff'", rendered)
        self.assertIn("gradient_color_3 = '#e9edf5'", rendered)

    def test_waybar_uses_semantic_palette_roles(self):
        rendered = render_waybar_spectrum(PALETTE)

        for role in ("background", "surface", "foreground", "muted", "accent", "success", "warning", "error"):
            self.assertIn(PALETTE.color(role), rendered)
        self.assertIn("#workspaces button.active", rendered)
        self.assertIn(".modules-left,", rendered)
        self.assertIn("window#waybar > box", rendered)
        self.assertIn("background: transparent;", rendered)
        self.assertNotIn("color1", rendered)
        self.assertNotIn(".cache/wal", rendered)

    def test_square_waybar_removes_rounding(self):
        spectrum = render_waybar_spectrum(PALETTE)
        square = render_waybar_square(PALETTE)

        self.assertIn("border-radius: 10px", spectrum)
        self.assertNotIn("border-radius: 10px", square)
        self.assertNotIn("border-radius: 7px", square)

    def test_workspaces_and_window_shape_follow_the_selected_style(self):
        # #workspaces and #window are containers (a box of buttons; a single label), not
        # individual per-status-module chips, so they sit outside the shared #clock/#cpu/...
        # block that already carries a shape-following radius -- without their own rule,
        # both painted a solid background (from _waybar_theme) with square GTK-default
        # corners no matter which shape was selected.
        spectrum = render_waybar_spectrum(PALETTE)
        square = render_waybar_square(PALETTE)
        for rendered, expected in ((spectrum, "border-radius: 7px"), (square, "border-radius: 0px")):
            block = rendered.split("#workspaces,\n#window {", 1)[1].split("}", 1)[0]
            self.assertIn(expected, block)

    def test_waybar_color_themes_remain_distinct_with_a_transparent_chrome(self):
        unified = render_waybar_spectrum(PALETTE)
        tonal = render_waybar_spectrum_tonal(PALETTE)
        prism = render_waybar_spectrum_prism(PALETTE)
        self.assertNotEqual(unified, tonal)
        self.assertNotEqual(tonal, prism)
        self.assertIn("background: @surface;", unified)
        self.assertIn("background: @surface_alt;\n    color: @accent;", tonal)
        self.assertIn("background: @accent_alt", prism)
        for rendered in (unified, tonal, prism):
            # Only the general bar chrome is transparent -- every module,
            # including the focused-window-title module, still gets its own
            # solid pill so nothing on the bar itself is ever see-through.
            self.assertIn("window#waybar {\n    background: transparent;", rendered)
            self.assertIn("#window {\n    background: @surface;", rendered)

    def test_waybar_reserves_solid_backgrounds_for_meaningful_states(self):
        rendered = render_waybar_spectrum_prism(PALETTE)
        self.assertIn("#workspaces button.active", rendered)
        self.assertIn("#custom-recorder.recording", rendered)
        self.assertIn("#battery.critical", rendered)
        # No module may fall back to a semi-transparent fill: every waybar
        # background is a solid, matte color so nothing behind the bar shows
        # through, no matter what window is open underneath it.
        self.assertNotIn("alpha(", rendered)

    def test_waybar_styles_the_performance_and_keep_awake_toggles(self):
        rendered = render_waybar_spectrum_prism(PALETTE)
        # Only "performance" gets the highlight, matching header-icon.active's own rule --
        # "balanced" is the everyday default and stays the plain chip look.
        self.assertIn("#custom-performance.performance", rendered)
        self.assertNotIn("#custom-performance.balanced", rendered)
        self.assertIn("#custom-keep-awake.active", rendered)
        # Fully collapses the module (no width/padding) when hidden, matching the same
        # treatment already given to custom-weather/gpu/cpu-temp/refresh when unavailable.
        self.assertIn("#custom-performance.unavailable", rendered)
        for theme_renderer in (
            render_waybar_spectrum, render_waybar_spectrum_tonal, render_waybar_spectrum_prism,
        ):
            self.assertIn("#custom-performance", theme_renderer(PALETTE))
            self.assertIn("#custom-keep-awake", theme_renderer(PALETTE))

    def test_performance_and_keep_awake_icons_get_extra_room_only_on_the_right(self):
        # md-coffee/md-coffee_off/md-speedometer/fa-scale_balanced all paint past their own
        # advance width (measured directly off the shipped Nerd Font files with fontTools --
        # fa-scale_balanced, the "balanced" state, overflows by roughly a full extra
        # character's width), which used to bleed past the standard symmetric 8px padding
        # into the pill's right edge. Left bearing on all four glyphs is negligible, so only
        # the right side needed more room; scales with font size like every other spacing
        # value here rather than a value baked in for one specific size.
        for size in (13, 16, 20):
            rendered = render_waybar_spectrum(PALETTE, size)
            block = rendered.split("#custom-keep-awake,\n#custom-performance {", 1)[1].split("}", 1)[0]
            match = re.search(r"padding:\s*0\s+(\d+)px\s+0\s+(\d+)px", block)
            self.assertIsNotNone(match, block)
            right, left = int(match.group(1)), int(match.group(2))
            self.assertEqual(left, 8)
            self.assertGreater(right, left)
            self.assertEqual(right, 8 + round(size * 0.6))

    def test_waybar_styles_the_native_calendar_tooltip(self):
        # The clock module's tooltip embeds a native GTK calendar ({calendar} in
        # tooltip-format); it must follow the active palette like every other
        # module rather than being left to GTK's unstyled default.
        rendered = render_waybar_spectrum(PALETTE)
        self.assertIn("calendar {", rendered)
        self.assertIn("calendar.header {", rendered)
        self.assertIn("calendar.button {", rendered)
        self.assertIn("calendar:selected {", rendered)
        selected_block = rendered.split("calendar:selected {", 1)[1].split("}", 1)[0]
        self.assertIn("background: @accent;", selected_block)
        self.assertIn("color: @background;", selected_block)
        self.assertNotIn("alpha(", rendered)

    def test_waybar_calendar_and_tooltip_follow_the_global_font_size(self):
        # GTK's own default theme already assigns tooltip/calendar text a font-size with
        # higher selector specificity than the bar's universal `*` rule, so the global
        # font-size control would silently lose to it unless restated on these selectors
        # directly rather than relying on inheritance from `*`.
        rendered = render_waybar_spectrum(PALETTE, 18)
        tooltip_block = rendered.split("tooltip {", 1)[1].split("}", 1)[0]
        self.assertIn("font-size: 18px;", tooltip_block)
        tooltip_label_block = rendered.split("tooltip label {", 1)[1].split("}", 1)[0]
        self.assertIn("font-size: 18px;", tooltip_label_block)
        calendar_block = rendered.split("calendar {", 1)[1].split("}", 1)[0]
        self.assertIn("font-size: 18px;", calendar_block)

    def test_waybar_cava_background_never_matches_the_bar_gradient(self):
        # waybar-cava draws each bar in an accent -> accent_alt gradient; a
        # themed module background (prism's solid @accent_alt fill, in
        # particular) can land on or near that gradient and make the moving
        # bars disappear into their own backdrop. The cava module must always
        # sit on a fixed, neutral dark background regardless of theme.
        for rendered in (
            render_waybar_spectrum(PALETTE),
            render_waybar_spectrum_tonal(PALETTE),
            render_waybar_spectrum_prism(PALETTE),
        ):
            self.assertIn("#custom-cava {\n", rendered)
            self.assertIn("background: @background;\n    color: @foreground;\n    min-width: 84px;", rendered)

    def test_wofi_profiles_use_semantic_colors(self):
        standard = render_wofi(PALETTE)
        wallpaper = render_wofi_wallpaper(PALETTE)

        for role in ("background", "surface", "foreground", "accent", "accent_alt"):
            self.assertIn(PALETTE.color(role), standard)
        self.assertIn("padding: 10px", wallpaper)
        self.assertIn("padding: 6px", standard)
        self.assertNotIn("color1", standard)
        self.assertNotIn(".cache/wal", standard)
        self.assertIn("#scroll scrollbar {", standard)
        self.assertIn("min-height: 0;", standard)
        self.assertIn("opacity: 0;", standard)
        self.assertIn("#scroll undershoot,", standard)
        self.assertIn("#scroll overshoot {", standard)
        self.assertIn("background: none;", standard)

    def test_wofi_has_more_color_than_a_flat_neutral_chrome(self):
        # The window border, input border, and icon frame used to lean on the muted/
        # surface_alt neutrals -- only the keyboard-selected row ever showed real color.
        # Now the window/input borders and icon frame carry an accent tint, hovering a
        # row (not just selecting it) shows a soft accent_alt tint, and the selected row
        # is a two-tone accent -> accent_alt gradient instead of a flat single hue.
        rendered = render_wofi(PALETTE)
        self.assertIn(f"border: 1px solid alpha({PALETTE.color('accent')}, 0.4);", rendered)
        self.assertIn(f"border: 1px solid alpha({PALETTE.color('accent')}, 0.3);", rendered)
        self.assertIn(f"background-color: alpha({PALETTE.color('accent_alt')}, 0.18);", rendered)
        self.assertIn(
            f"background-image: linear-gradient(135deg, {PALETTE.color('accent')}, {PALETTE.color('accent_alt')});",
            rendered,
        )
        self.assertIn(f"border: 1px solid alpha({PALETTE.color('accent_alt')}, 0.35);", rendered)

    def test_eww_uses_the_full_semantic_palette(self):
        rendered = render_eww(PALETTE)
        for role in ("accent", "accent_alt", "success", "warning"):
            self.assertIn(PALETTE.color(role), rendered)
        self.assertIn(".metric-card.tone-success", rendered)
        self.assertIn(".size-button-selected", rendered)
        self.assertIn(".choice-button-selected", rendered)
        self.assertIn("box-shadow: inset", rendered)
        self.assertIn(".settings-card.tone-warning", rendered)
        self.assertIn("border-left: 4px solid", rendered)
        self.assertIn(".header-weather", rendered)
        self.assertIn(".weather-current", rendered)
        self.assertIn(".window-effects-card", rendered)
        self.assertIn(".weather-location-remove", rendered)
        self.assertNotIn(".spectrum-visualizer", rendered)

    def test_global_font_size_reaches_all_supported_consumers(self):
        self.assertIn("font-size: 18px", render_waybar_spectrum(PALETTE, 18))
        self.assertIn("font-size: 18px", render_wofi(PALETTE, 18))
        self.assertIn("font-size: 18px", render_eww(PALETTE, 18))
        self.assertIn("font_size 18", render_kitty(PALETTE, 18))
        self.assertIn("size = 18.0", render_alacritty(PALETTE, 18))
        self.assertIn(PALETTE.color("accent"), render_alacritty(PALETTE, 18))
        self.assertIn("JetBrainsMono Nerd Font 18", render_dunst(PALETTE, 18))
        self.assertIn("font_size = 108", render_hyprlock(PALETTE, 18))
        self.assertIn("/var/lib/spectrumos/appearance/lock-branding.png", render_hyprlock(PALETTE, 18))
        self.assertIn("size = 378", render_hyprlock(PALETTE, 18))
        self.assertIn("border_size = 0", render_hyprlock(PALETTE, 18))
        self.assertIn("rounding = 0", render_hyprlock(PALETTE, 18))

    def test_eww_panel_uses_semantic_roles(self):
        rendered = render_eww(PALETTE)
        for role in ("background", "surface", "surface_alt", "foreground", "muted", "accent", "accent_alt"):
            self.assertIn(PALETTE.color(role), rendered)
        self.assertIn(".spectrum-action:hover", rendered)

    def test_gtk_uses_semantic_roles(self):
        rendered = render_gtk(PALETTE)
        for role in ("background", "surface", "foreground", "muted", "accent", "success", "warning", "error"):
            self.assertIn(PALETTE.color(role), rendered)
        self.assertIn(".view,", rendered)
        self.assertIn("filechooser .dialog-action-box", rendered)
        self.assertIn("window.csd decoration,", rendered)
        self.assertIn("window.solid-csd decoration", rendered)
        self.assertIn("margin: 0;", rendered)
        self.assertIn("box-shadow: none;", rendered)
        self.assertIn("background-image: none", rendered)
        self.assertNotIn(".cache/wal", rendered)

    def test_gtk_styles_notebook_content(self):
        rendered = render_gtk(PALETTE)
        content_rule = rendered.split("notebook > stack,", 1)[1].split("}", 1)[0]
        self.assertIn("background-color: @theme_base_color;", content_rule)
        self.assertIn("color: @theme_text_color;", content_rule)
        self.assertNotIn(":focus-within", rendered)

    def test_gtk_selection_overrides_file_view_surface(self):
        rendered = render_gtk(PALETTE)
        view_rule = rendered.index(".view,\niconview,")
        selection_rule = rendered.index("selection,\n*:selected,")
        self.assertLess(view_rule, selection_rule)
        selected = rendered[selection_rule:].split("}", 1)[0]
        self.assertIn("background-color: @theme_selected_bg_color;", selected)
        self.assertIn("color: @theme_selected_fg_color;", selected)

    def test_gtk_defines_libadwaita_named_colors_for_gtk4_apps(self):
        # Libadwaita (GTK4) apps never read the classic "theme_*" names above -- they use their
        # own documented named-color contract for accent/window/view/headerbar/card/dialog/
        # popover. Without these, a libadwaita app (including the file chooser xdg-desktop-
        # portal-gtk draws on behalf of apps with no GTK of their own, e.g. Electron) falls back
        # to Adwaita's stock colors and an unselected-looking list, regardless of the palette.
        rendered = render_gtk(PALETTE)
        mapped = {
            "accent_color": "accent",
            "accent_bg_color": "accent",
            "accent_fg_color": "background",
            "destructive_bg_color": "error",
            "success_bg_color": "success",
            "warning_bg_color": "warning",
            "error_bg_color": "error",
            "window_bg_color": "background",
            "window_fg_color": "foreground",
            "view_bg_color": "surface",
            "headerbar_bg_color": "surface",
            "card_bg_color": "surface",
            "dialog_bg_color": "background",
            "popover_bg_color": "surface",
        }
        for name, role in mapped.items():
            self.assertIn(f"@define-color {name} {PALETTE.color(role)};", rendered)

    def test_neovim_uses_semantic_palette_without_pywal(self):
        rendered = render_neovim(PALETTE)
        for role in PALETTE.roles:
            self.assertIn(PALETTE.color(role), rendered)
        self.assertIn('vim.g.colors_name = "spectrum"', rendered)
        self.assertNotIn("pywal", rendered.lower())
        self.assertNotIn("lushwal", rendered.lower())

    def test_folder_icons_follow_semantic_palette(self):
        self.assertIn(PALETTE.color("accent"), render_folder(PALETTE))
        self.assertIn(PALETTE.color("accent"), render_folder_downloads(PALETTE))
        self.assertIn(PALETTE.color("background"), render_folder(PALETTE))

    def test_dunst_has_icons_progress_and_integrated_rules(self):
        rendered = render_dunst(PALETTE)
        for value in (
            "progress_bar = true", "enable_recursive_icon_lookup = true", "icon_position = left",
            "[volume]", "[brightness]", "[network]", "[zen-browser]", "[spotify]", "[steam]",
        ):
            self.assertIn(value, rendered)
        for role in ("accent", "success", "warning", "error"):
            self.assertIn(PALETTE.color(role), rendered)
        icon = render_dunst_volume_icon(PALETTE)
        self.assertIn(PALETTE.color("foreground"), icon)
        self.assertIn("<svg", icon)

    def test_qt_uses_semantic_roles(self):
        for rendered in (render_kvantum(PALETTE), render_qt_colors(PALETTE)):
            for role in ("background", "surface", "foreground", "muted", "accent", "accent_alt"):
                self.assertIn(PALETTE.color(role), rendered)
        self.assertIn("theme=", "theme=Spectrum")
        self.assertIn("no_window_pattern=true", render_kvantum(PALETTE))
        self.assertIn('id="button-focused"', render_kvantum_svg(PALETTE))

    def test_qt_buttons_use_a_fixed_radius_nine_patch_not_a_proportional_rect(self):
        # Kvantum draws every widget from named nine-patch pieces (a center, four edges and
        # four corners per state) and reads the corner's pixel size from frame.top/bottom/
        # left/right in the .kvconfig. Earlier this theme declared no widget sections at all
        # and drew each button as a single <rect rx="4"> on a 16px tile (a 25% corner) --
        # Kvantum couldn't find real frame data, fell back to its own default geometry, and
        # a proportional 25% radius on a small square control reads as a near-circle rather
        # than a subtly rounded rectangle. This guards against both mistakes recurring.
        config = render_kvantum(PALETTE)
        svg = render_kvantum_svg(PALETTE)

        # PanelButtonCommand and ToolTip declare their own frame.top/bottom/left/right
        # directly; LineEdit/ComboBox reuse the exact same "button" nine-patch and radius by
        # inheriting from PanelButtonCommand rather than restating the numbers.
        for section, radius in (("PanelButtonCommand", KVANTUM_BUTTON_RADIUS), ("ToolTip", KVANTUM_TOOLTIP_RADIUS)):
            self.assertIn(f"[{section}]", config)
            body = config.split(f"[{section}]", 1)[1].split("\n[", 1)[0]
            for side in ("top", "bottom", "left", "right"):
                self.assertIn(f"frame.{side}={radius}", body)
        self.assertIn("frame.element=button", config.split("[PanelButtonCommand]", 1)[1].split("\n[", 1)[0])
        self.assertIn("frame.element=tooltip", config.split("[ToolTip]", 1)[1].split("\n[", 1)[0])

        for section in ("LineEdit", "ComboBox"):
            self.assertIn(f"[{section}]", config)
            body = config.split(f"[{section}]", 1)[1].split("\n[", 1)[0]
            self.assertIn("inherits=PanelButtonCommand", body)
            self.assertIn("frame.element=button", body)

        for section in ("CheckBox", "RadioButton"):
            self.assertIn(f"[{section}]", config)
            body = config.split(f"[{section}]", 1)[1].split("\n[", 1)[0]
            self.assertIn("inherits=PanelButtonCommand", body)
            self.assertIn(f"indicator.size={KVANTUM_INDICATOR_SIZE}", body)

        self.assertIn("[Focus]", config)

        # Cada estado de boton debe traer las 9 piezas reales -- no un solo rect con rx.
        for state in ("normal", "focused", "pressed", "toggled"):
            for suffix in ("", "-top", "-bottom", "-left", "-right", "-topleft", "-topright", "-bottomleft", "-bottomright"):
                self.assertIn(f'id="button-{state}{suffix}"', svg)
        for suffix in ("", "-top", "-bottom", "-left", "-right", "-topleft", "-topright", "-bottomleft", "-bottomright"):
            self.assertIn(f'id="tooltip-normal{suffix}"', svg)
        for suffix in ("topleft", "topright", "bottomleft", "bottomright", "top", "bottom", "left", "right"):
            self.assertIn(f'id="focus-{suffix}"', svg)
        for role in ("checkbox-normal", "checkbox-focused", "checkbox-checked-normal", "radio-normal", "radio-focused", "radio-checked-normal"):
            self.assertIn(f'id="{role}"', svg)

        # El bug original era exactamente esto: un solo <rect rx="4"> por estado, con el radio
        # proporcional al tile en vez de un nine-patch de tamano fijo. checkbox/radio si usan
        # rx legitimamente porque son glifos de tamano constante, no controles que se estiran.
        for tag in re.findall(r"<rect[^>]*>", svg):
            if 'id="button' in tag or 'id="tooltip' in tag:
                self.assertNotIn("rx=", tag)

    def test_qt_button_corners_form_a_seamless_rounded_rectangle(self):
        # Extracts the four corner paths generated for button-normal and checks their arc
        # geometry actually meets at shared points with no gap or overlap when assembled at
        # the corners of a rectangle -- the exact defect that produced the reported "circle"
        # look would instead show up here as a radius that does not match KVANTUM_BUTTON_RADIUS.
        svg = render_kvantum_svg(PALETTE)
        r = KVANTUM_BUTTON_RADIUS
        expected = {
            "button-normal-topleft": f"M 0,{r} A {r},{r} 0 0 1 {r},0 L {r},{r} Z",
            "button-normal-topright": f"M {r},{r} A {r},{r} 0 0 0 0,0 L 0,{r} Z",
            "button-normal-bottomleft": f"M 0,0 A {r},{r} 0 0 0 {r},{r} L {r},0 Z",
            "button-normal-bottomright": f"M {r},0 A {r},{r} 0 0 1 0,{r} L 0,0 Z",
        }
        for element_id, path in expected.items():
            self.assertIn(f'id="{element_id}" d="{path}"', svg)

    def test_application_templates_use_semantic_roles_without_pywal(self):
        # Discord's own "Custom Theme" builder was removed from the client;
        # Vencord's QuickCSS (loaded automatically, no manual paste step) is
        # the mechanism that actually works, so it overrides Discord's own
        # theming custom properties directly.
        vencord = render_vencord_theme(PALETTE)
        telegram = render_telegram_theme(PALETTE)

        self.assertIn(":root {", vencord)
        self.assertIn("--background-primary: #101218;", vencord)
        self.assertIn("--text-normal: #e9edf5;", vencord)
        self.assertIn("--brand-experiment: #76b7ff;", vencord)
        self.assertIn("windowBg: #101218;", telegram)
        self.assertIn("windowBgActive: #76b7ff;", telegram)
        self.assertNotIn("pywal", (vencord + telegram).lower())

    def test_zen_browser_uses_firefox_lwt_and_zen_custom_properties(self):
        # Firefox's own Lightweight Theme variables are the reliable baseline (stable for
        # years, inherited by any Firefox-fork toolkit). --zen-primary-color is the one
        # input Zen's own CSS computes its whole --zen-colors-* ramp from (confirmed by
        # reading zen-theme.css) -- overriding that single input, not the derived colors,
        # keeps the ramp internally consistent. --zen-main-browser-background is the
        # actual visible window background, hardcoded by Zen with no reference to the
        # accent/branding variables at all -- confirmed the window stayed unthemed without
        # it. Every declaration needs !important: Zen's own zen-theme.css sets these same
        # properties on the same :root selector, a specificity tie broken only by load
        # order without it -- and :root:root:root outweighs the higher-specificity
        # `:root[zen-unsynced-window="true"]`-style selectors Zen uses to re-declare some
        # of these same properties (also !important) for a fresh/unlinked profile, which
        # would otherwise still win over a plain `:root` rule despite matching !important.
        rendered = render_zen_browser_theme(PALETTE)
        self.assertIn(":root:root:root {", rendered)
        self.assertIn("--zen-themed-toolbar-bg-transparent: #101218 !important;", rendered)
        self.assertIn("--lwt-accent-color: #101218 !important;", rendered)
        self.assertIn("--lwt-text-color: #e9edf5 !important;", rendered)
        self.assertIn("--toolbar-bgcolor: #191c24 !important;", rendered)
        self.assertIn("--zen-primary-color: #76b7ff !important;", rendered)
        self.assertIn("--zen-branding-dark: #101218 !important;", rendered)
        self.assertIn("--zen-branding-paper: #101218 !important;", rendered)
        self.assertIn("--zen-main-browser-background: #101218 !important;", rendered)
        self.assertNotIn("pywal", rendered.lower())

    def test_zen_extension_manifest_is_a_valid_static_theme(self):
        # A real WebExtension theme add-on, sideloaded rather than only relying on
        # userChrome.css -- confirmed by reading Zen's own LightweightThemeConsumer.sys.mjs
        # that an active theme add-on makes Firefox/Zen's official pipeline inline-set
        # every --lwt-* variable itself, sidestepping the internal cascade fight entirely.
        manifest = json.loads(render_zen_extension_manifest(PALETTE))
        self.assertEqual(manifest["manifest_version"], 2)
        self.assertEqual(manifest["browser_specific_settings"]["gecko"]["id"], "spectrumos-theme@spectrumos.dev")
        colors = manifest["theme"]["colors"]
        self.assertEqual(colors["frame"], "#101218")
        self.assertEqual(colors["toolbar"], "#191c24")
        self.assertEqual(colors["toolbar_text"], "#e9edf5")
        self.assertEqual(colors["tab_line"], "#76b7ff")
        self.assertEqual(colors["sidebar"], "#101218")
        self.assertNotIn("pywal", json.dumps(manifest).lower())


if __name__ == "__main__":
    unittest.main()

-- Minimal live/installer session. Deliberately not the full desktop entrypoint
-- (configs/hyprland/hyprland.lua) -- that one requires theme-engine caches,
-- per-user overrides, and adapters that don't exist on the bare live medium.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("GDK_BACKEND", "wayland,x11")

-- Kept out of the compositor's direct process tree the same way the full
-- desktop's own autostart.lua does -- spectrum-live-session is now uwsm-managed
-- again (it's the account's login shell, not a /etc/profile.d fragment uwsm's
-- own preloader would re-source and recurse into -- see that file's comment),
-- so `uwsm app` has a real session to attach these to.
hl.on("hyprland.start", function()
    hl.exec_cmd("uwsm app -s s -- swaybg -m fill -i /usr/share/spectrumos/installer/wallpaper.png")
    hl.exec_cmd("uwsm app -s s -- /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("uwsm app -s s -- nm-applet --indicator")
    hl.exec_cmd("uwsm app -s s -- qs --path /usr/share/spectrumos/installer/shell --no-duplicate")
    hl.exec_cmd("uwsm app -s s -- /usr/local/bin/spectrum-installer")
end)

hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
        },
    },
    general = {
        gaps_in = 5,
        gaps_out = 12,
        border_size = 2,
        col = {
            active_border = { colors = { "rgba(70a0d0ff)", "rgba(c28ae7ff)" }, angle = 45 },
            inactive_border = "rgba(334155aa)",
        },
        layout = "dwindle",
    },
    decoration = {
        rounding = 14,
    },
    animations = {
        enabled = true,
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
    },
})

-- El panel conserva su posición cuando se abre o cierra la ventana de red.
hl.layer_rule({
    name = "spectrum-live-shell-motion",
    match = { namespace = "^spectrum-live-(bar|network)$" },
    no_anim = true,
})

local mainMod = "SUPER"
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("uwsm app -- foot"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("uwsm app -- /usr/local/bin/spectrum-installer"))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("uwsm app -- foot --title=\"Rescue system\" -e /usr/local/bin/spectrum-rescue-shell"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("uwsm app -- /usr/local/bin/spectrum-live-network"))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exit())

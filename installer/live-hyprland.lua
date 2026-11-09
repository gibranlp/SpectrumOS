package.path = "/usr/share/spectrumos/hyprland/?.lua;" .. package.path

require("monitors")
require("environment")
require("input")
require("appearance")
require("animations")
require("layouts")
require("window-rules")
require("keybindings")
dofile(os.getenv("HOME") .. "/.cache/spectrumos/theme/current/hyprland.lua")

-- La sesión usa el escritorio normal; la bienvenida deja explorar antes de instalar.
hl.on("hyprland.start", function()
    hl.exec_cmd("uwsm app -s s -- /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("uwsm app -s s -- awww-daemon")
    hl.exec_cmd("uwsm app -s s -- /usr/lib/spectrumos/wallpaper-restore")
    hl.exec_cmd("uwsm app -s s -- /usr/lib/spectrumos/appearance-sync --apply")
    hl.exec_cmd("systemctl --user start spectrum-resource-monitor.service spectrum-workspace-layout.service spectrum-shell.service")
    hl.exec_cmd("uwsm app -s s -- /usr/local/bin/spectrum-live-welcome")
end)

hl.bind("SUPER + CTRL + I", hl.dsp.exec_cmd("uwsm app -- /usr/local/bin/spectrum-installer"))
hl.bind("SUPER + CTRL + R", hl.dsp.exec_cmd("uwsm app -- foot --title=\"Rescue system\" -e /usr/local/bin/spectrum-rescue-shell"))

hl.layer_rule({
    name = "spectrum-live-shell-motion",
    match = { namespace = "^spectrum-live-(bar|network)$" },
    no_anim = true,
})

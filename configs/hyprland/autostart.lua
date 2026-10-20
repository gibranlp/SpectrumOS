-- UWSM conserva cada proceso importante fuera del árbol directo del compositor.
hl.on("hyprland.start", function()
    hl.exec_cmd("uwsm app -s s -- /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("uwsm app -s s -- awww-daemon")
    hl.exec_cmd("uwsm app -s s -- /usr/lib/spectrumos/wallpaper-restore")
    hl.exec_cmd("uwsm app -s s -- /usr/lib/spectrumos/appearance-sync --apply")
    hl.exec_cmd("systemctl --user start spectrum-resource-monitor.service")
    hl.exec_cmd("/usr/lib/spectrumos/mouse-adapter --apply")
    hl.exec_cmd("systemctl --user start spectrum-shell.service")
    hl.exec_cmd("systemctl --user start spectrum-questline-notifications.service")
    hl.exec_cmd("systemctl --user start spectrum-questline-sync.service")
    hl.exec_cmd("uwsm app -s s -- hypridle -c /usr/share/spectrumos/hyprland/hypridle.conf")
    hl.exec_cmd("uwsm app -s s -- blueman-applet")
    hl.exec_cmd("systemctl --user start spectrum-workspace-layout.service")
end)

-- `persistent = true` workspace_rule only protects an *already-created* empty workspace
-- from being destroyed when its last window closes -- confirmed live, a plain
-- `hyprctl reload` (every theme/font/waybar/hyprland-menu setting change triggers one)
-- still destroys an empty persistent workspace outright, rule or no rule. Re-running
-- --apply here on every reload recreates whichever of 1-6 that reload just wiped (it's a
-- no-op once they already exist), which is what actually keeps the always-1-5-then-6
-- split showing in Waybar no matter how many settings get changed afterward.
hl.on("config.reloaded", function()
    hl.exec_cmd("/usr/lib/spectrumos/workspace-layout --apply")
end)

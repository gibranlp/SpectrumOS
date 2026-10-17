hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 5,
        border_size = 3,
        col = {
            active_border = { colors = { "rgb(76b7ff)", "rgb(c49aff)" }, angle = 45 },
            inactive_border = "rgb(9ca6b8)",
        },
        layout = "dwindle",
        allow_tearing = false,
    },
    decoration = {
        rounding = 10,
        blur = { enabled = true, size = 3, passes = 1, new_optimizations = true, xray = true },
        shadow = { enabled = true, range = 12, render_power = 3, color = "rgba(00000040)" },
    },
    misc = {
        disable_hyprland_logo = true,
        force_default_wallpaper = 0,
    },
})

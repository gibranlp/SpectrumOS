hl.config({
    dwindle = { preserve_split = true, smart_resizing = true },
    master = { new_status = "slave", mfact = 0.5, orientation = "left" },
    -- Without this, fullscreening any window (a game, a video) drops every pinned
    -- window's pin -- the exact "picture-in-picture over a fullscreen game" case
    -- Super+Shift+Space (window-pin-toggle) exists for. This keeps pinned windows
    -- pinned through a fullscreen event instead of silently un-pinning them.
    binds = { allow_pin_fullscreen = true },
})

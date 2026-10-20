local mainMod = "SUPER"
local windowActions = require("window-actions")
hl.bind(mainMod .. " + SHIFT + U", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open app-store"))
hl.bind(mainMod .. " + F10", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open bar"))

-- Aplicaciones y sesión
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("uwsm app -- kitty"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
-- `hyprctl kill` (not a `dispatch`, a standalone request) puts the cursor into a crosshair
-- kill mode -- click any window to force it closed, for one that Super+Q's graceful close
-- doesn't affect (unresponsive, no window-close handler, etc.). Escape is kill mode's own
-- built-in cancel key, so binding it on a *press* races kill mode's own escape-to-cancel
-- handling and can exit the mode before a click ever lands (confirmed: a known Hyprland
-- quirk, see hyprwm/Hyprland discussion #14664) -- `release = true` defers firing until
-- the key is let go, after that race has already resolved.
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("hyprctl kill"), { release = true })
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("uwsm app -- thunar"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-launcher"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open calculator"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open control"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock -c $HOME/.cache/spectrumos/theme/current/hyprlock.conf"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open wallpapers"))
-- Only the wallpaper is random here -- the currently selected palette backend, dark/light
-- variant, and gowall filter all keep applying to it. "Surprise me" in the control center
-- is the one that rerolls every axis at once; this is a quicker, narrower "next wallpaper".
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("/usr/lib/spectrumos/theme-menu --random-wallpaper"))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open control"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open power"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open audio"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open network"))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open password"))
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open color"))
hl.bind(mainMod .. " + SHIFT + I", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open color-history"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open search"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open emoji"))
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open session"))
hl.bind("CTRL + ALT + Pause", hl.dsp.exec_cmd("/usr/lib/spectrumos/hotkey-adapter stop-all"))
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open spectrumdrop"))
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open hotkey"))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open favorites"))
hl.bind(mainMod .. " + K", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open shortcuts"))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.exec_cmd("/usr/bin/spectrum-ukvm"))
hl.bind(mainMod .. " + U", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open updates"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open new-task"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open new-scroll"))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open time"))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open questline"))
hl.bind("Print", hl.dsp.exec_cmd("/usr/lib/spectrumos/panel --capture"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("/usr/lib/spectrumos/panel --screenshot-area"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("/usr/lib/spectrumos/theme-adapter random"))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open mouse"))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open audio-recorder"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open recorder"))

hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open appimages"))
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open appearance"))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open bluetooth"))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open calendar"))
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open dashboard"))
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open displays"))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open focus"))
hl.bind(mainMod .. " + SHIFT + X", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open more"))
hl.bind(mainMod .. " + SHIFT + Y", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open typography"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open weather"))

-- Estado y acomodo de ventanas
hl.bind(mainMod .. " + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + J", windowActions.arrange)
hl.bind(mainMod .. " + Tab", function() windowActions.cycle(true) end)
hl.bind(mainMod .. " + SHIFT + Tab", function() windowActions.cycle(false) end)
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
-- Floats the window if it isn't already, then pins it in place across every workspace --
-- a picture-in-picture-style "stays exactly here no matter where I navigate". Pressing
-- it again on the same window un-pins and leaves it a normal floating window.
hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.exec_cmd("/usr/lib/spectrumos/window-pin-toggle"))

-- Notificaciones
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open notifications"))
hl.bind("CTRL + Space", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open dismiss-notification"))
hl.bind("CTRL + SHIFT + Space", hl.dsp.exec_cmd("/usr/lib/spectrumos/spectrum-shell-open clear-notifications"))

-- Audio, reproducción y brillo
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("/usr/lib/spectrumos/volume up"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("/usr/lib/spectrumos/volume down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("/usr/lib/spectrumos/volume mute"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("/usr/lib/spectrumos/media-control toggle"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("/usr/lib/spectrumos/media-control next"), { locked = true })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("/usr/lib/spectrumos/media-control stop"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("/usr/lib/spectrumos/media-control previous"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("/usr/lib/spectrumos/brightness up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("/usr/lib/spectrumos/brightness down"), { locked = true, repeating = true })

for _, direction in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mainMod .. " + " .. direction, function() windowActions.focus(direction) end)
    hl.bind(mainMod .. " + SHIFT + " .. direction, function() windowActions.move(direction) end)
end

-- hl.dsp.window.resize({ x, y, relative = true }), not exec_cmd("hyprctl dispatch
-- resizeactive ...") -- confirmed live that this Hyprland version's `hyprctl dispatch`
-- no longer takes the classic "dispatcher arg1 arg2" form (it evaluates its argument as
-- Lua, so multiple bare words there is a parse error); the native hl.dsp call sidesteps
-- that entirely, the same way focus/move above already do.
for direction, delta in pairs({
    left = { x = -20, y = 0 },
    right = { x = 20, y = 0 },
    up = { x = 0, y = -20 },
    down = { x = 0, y = 20 },
}) do
    hl.bind(mainMod .. " + CTRL + " .. direction, hl.dsp.window.resize({ x = delta.x, y = delta.y, relative = true }))
end

for workspace = 1, 6 do
    hl.bind(mainMod .. " + " .. workspace, hl.dsp.focus({ workspace = workspace }))
    -- Two prior attempts here didn't pan out: `hl.dsp.window.move({workspace=...,
    -- silent=true})` still followed the window (confirmed live, even though the same
    -- field works for scripts/workspace-layout's own call to that function), and routing
    -- through `hyprctl dispatch movetoworkspacesilent` did nothing at all (also confirmed
    -- live). This instead does the move-then-return explicitly: capture whichever
    -- workspace is active right now, dispatch the plain (following) move, then dispatch
    -- a focus back to that captured workspace -- self-contained, doesn't depend on any
    -- dispatcher's own "don't follow" semantics actually doing what its name suggests.
    hl.bind(mainMod .. " + SHIFT + " .. workspace, function()
        local origin = hl.get_active_workspace()
        hl.dispatch(hl.dsp.window.move({ workspace = workspace }))
        if origin then
            hl.dispatch(hl.dsp.focus({ workspace = origin.id }))
        end
    end)
end

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

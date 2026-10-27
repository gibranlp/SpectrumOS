-- Este orden mantiene separados los defaults, el tema generado y los ajustes locales.
package.path = "/usr/share/spectrumos/hyprland/?.lua;" .. package.path

require("monitors")
require("environment")
require("input")
require("appearance")
require("animations")
require("layouts")
require("window-rules")
require("autostart")
require("keybindings")

local home = os.getenv("HOME")

local function load_optional(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        dofile(path)
    end
end

dofile(home .. "/.cache/spectrumos/theme/current/hyprland.lua")
-- Installer-generated, GPU-profile-specific env vars (e.g. nvidia rendering
-- vars for a discrete-only install) -- kept separate from machine.lua so the
-- installer can safely regenerate it on re-runs without clobbering whatever a
-- person has hand-edited into machine.lua themselves.
load_optional("/etc/spectrumos/hyprland/gpu.lua")
load_optional("/etc/spectrumos/hyprland/machine.lua")
load_optional(home .. "/.config/spectrumos/hyprland-monitors.lua")
load_optional(home .. "/.config/spectrumos/hyprland-workspaces.lua")
load_optional(home .. "/.config/spectrumos/hyprland-lean.lua")
load_optional(home .. "/.config/spectrumos/hyprland-controls.lua")
load_optional(home .. "/.config/spectrumos/keyboard-layout.lua")
load_optional(home .. "/.config/spectrumos/hyprland.lua")

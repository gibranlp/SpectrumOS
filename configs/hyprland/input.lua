hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = true,
            disable_while_typing = true,
            tap_to_click = true,
            middle_button_emulation = true,
        },
    },
})

local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
for _, name in ipairs({ "mouse.lua", "mouse-cursor.lua" }) do
    local path = config_home .. "/spectrumos/" .. name
    local file = io.open(path, "r")
    if file then
        file:close()
        dofile(path)
    end
end

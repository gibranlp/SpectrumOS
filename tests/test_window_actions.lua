local modulePath = assert(arg[1])
local current, special, floating, events
local function event(kind, value) return {kind = kind, value = value} end
hl = {
    get_config = function() return "right" end,
    get_active_workspace = function() return current end,
    get_active_special_workspace = function() return special end,
    get_active_window = function() return {floating = floating} end,
    dispatch = function(action) events[#events + 1] = action end,
    workspace_rule = function(rule) events[#events + 1] = event("rule", rule) end,
    dsp = {
        layout = function(value) return event("layout", value) end,
        focus = function(value) return event("focus", value) end,
        window = {
            move = function(value) return event("move", value) end,
            swap = function(value) return event("swap", value) end,
            cycle_next = function(value) return event("cycle", value) end,
        },
    },
}
local actions = dofile(modulePath)
local checks = 0
local function expect(condition) checks = checks + 1; assert(condition, "check " .. checks) end
for _, layout in ipairs({"dwindle", "master", "scrolling", "monocle"}) do
    current = {id = 9, name = "9", tiled_layout = layout}; special = nil; floating = false; events = {}
    actions.arrange()
    local action = events[#events]
    if layout == "dwindle" then expect(action.value == "togglesplit") end
    if layout == "master" then expect(action.value == "orientationcycle left top") end
    if layout == "scrolling" then
        expect(action.value.workspace == "name:9" and action.value.layout_opts.direction == "down")
        actions.arrange(); expect(events[#events].value.layout_opts.direction == "right")
    end
    if layout == "monocle" then expect(action.value == "cyclenext") end
    for _, direction in ipairs({"left", "right", "up", "down"}) do
        actions.focus(direction); action = events[#events]
        expect(layout == "monocle" and action.kind == "layout" or action.kind == "focus" and action.value.direction == direction)
        actions.move(direction); action = events[#events]
        expect(layout == "monocle" and action.kind == "swap" or action.kind == "move" and action.value.direction == direction)
    end
    for _, next in ipairs({true, false}) do
        actions.cycle(next); action = events[#events]
        expect(layout == "monocle" and action.value == (next and "cyclenext" or "cycleprev") or action.kind == "cycle" and action.value.next == next)
    end
end
floating = true; actions.focus("left"); expect(events[#events].kind == "focus")
actions.move("left"); expect(events[#events].kind == "move")
actions.cycle(false); expect(events[#events].kind == "cycle")
special = {id = -99, special = true, name = "special:notes", tiled_layout = "scrolling"}
actions.arrange(); expect(events[#events].value.workspace == "special:notes")
special = nil; current = {id = -1337, name = "named", tiled_layout = "scrolling"}
actions.arrange(); expect(events[#events].value.workspace == "name:named")
current = nil; special = nil; events = {}; actions.arrange(); expect(#events == 0)
print(checks .. " layout routing checks passed")

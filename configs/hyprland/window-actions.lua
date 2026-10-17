local actions = {}
local scrollingDirections = {}

local function workspace()
    return hl.get_active_special_workspace() or hl.get_active_workspace()
end

local function tiledMonocle()
    local current = workspace()
    local window = hl.get_active_window()
    return current and current.tiled_layout == "monocle" and window and not window.floating
end

local function backwards(direction)
    return direction == "left" or direction == "up"
end

function actions.arrange()
    local current = workspace()
    if not current then return end
    if current.tiled_layout == "dwindle" then
        hl.dispatch(hl.dsp.layout("togglesplit"))
    elseif current.tiled_layout == "master" then
        hl.dispatch(hl.dsp.layout("orientationcycle left top"))
    elseif current.tiled_layout == "scrolling" then
        -- La regla se limita al espacio actual; no cambia la orientación de los demás.
        local selector = current.special and current.name or "name:" .. current.name
        local previous = scrollingDirections[selector] or hl.get_config("scrolling.direction")
        local direction = (previous == "down" or previous == "up") and "right" or "down"
        scrollingDirections[selector] = direction
        hl.workspace_rule({ workspace = selector, layout_opts = { direction = direction } })
    elseif current.tiled_layout == "monocle" then
        hl.dispatch(hl.dsp.layout("cyclenext"))
    end
end

function actions.focus(direction)
    if tiledMonocle() then
        hl.dispatch(hl.dsp.layout(backwards(direction) and "cycleprev" or "cyclenext"))
    else
        hl.dispatch(hl.dsp.focus({ direction = direction }))
    end
end

function actions.move(direction)
    if tiledMonocle() then
        -- En Monocle se reordena la pila, sin mandar la ventana a otra pantalla.
        hl.dispatch(hl.dsp.window.swap(backwards(direction) and { prev = true } or { next = true }))
    else
        hl.dispatch(hl.dsp.window.move({ direction = direction }))
    end
end

function actions.cycle(next)
    if tiledMonocle() then
        hl.dispatch(hl.dsp.layout(next and "cyclenext" or "cycleprev"))
    else
        hl.dispatch(hl.dsp.window.cycle_next({ next = next }))
    end
end

return actions

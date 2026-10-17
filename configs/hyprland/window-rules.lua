local floatingClasses = "^(pavucontrol|blueman-manager|nm-connection-editor|xdg-desktop-portal-gtk)$"
local fileDialogTitles = "^(Save File|Open File|Select a File|Open Folder|Save As)$"
local floatingTitles = "^(Picture-in-Picture|Save File|Open File|Select a File|Open Folder|Save As)$"

hl.window_rule({ name = "spectrum-floating-classes", match = { class = floatingClasses }, float = true })
hl.window_rule({ name = "spectrum-floating-dialogs", match = { title = floatingTitles }, float = true })
hl.window_rule({ name = "spectrum-file-dialog-border", match = { title = fileDialogTitles }, border_size = 0, no_blur = true })
-- El selector de archivos nativo (usado por apps sin GTK propio, como Electron) no lo dibuja la
-- app: lo dibuja xdg-desktop-portal-gtk, un servicio aparte que corre siempre en segundo plano.
-- Sin esta regla, ese dialogo hereda el blur global (pensado para paneles grandes), y si su
-- propia ventana GTK no queda opaca se ve como un marco translucido y borroso enorme alrededor
-- de un dialogo chico.
hl.window_rule({ name = "spectrum-portal-file-chooser-blur", match = { class = "^(xdg-desktop-portal-gtk)$" }, no_blur = true })
hl.window_rule({
    name = "spectrum-gamescope",
    match = { class = "^(gamescope)$" },
    fullscreen = true,
    no_anim = true,
    no_blur = true,
})

hl.layer_rule({
    name = "spectrum-control-center-motion",
    match = { namespace = "^spectrum-panel$" },
    animation = "fade",
})

-- Los widgets ya animan su contenido; mover también la capa separa las uniones del marco.
hl.layer_rule({
    name = "spectrum-widget-content-motion",
    match = { namespace = "^spectrum-widget-.*$" },
    no_anim = true,
})

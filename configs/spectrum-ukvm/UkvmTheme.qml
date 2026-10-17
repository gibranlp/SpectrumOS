import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: theme
    property bool active: false
    required property string palettePath
    required property string fontPath
    property var colors: ({background:"#15131a", surface:"#232029", surface_alt:"#2e2c34", foreground:"#eff3fa", muted:"#a6afbe", accent:"#b293e6"})
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 12

    function reload(): void {
        paletteFile.reload();
        fontFile.reload();
    }
    onActiveChanged: if (active) reload()
    // El enlace current cambia de destino sin modificar el archivo que vigila FileView.
    Timer {
        interval: 1000
        running: theme.active
        repeat: true
        onTriggered: theme.reload()
    }
    FileView {
        id: paletteFile
        path: theme.palettePath
        watchChanges: true
        onFileChanged: reload()
        onTextChanged: {
            try {
                const palette = JSON.parse(text());
                if (palette.roles && typeof palette.roles === "object")
                    theme.colors = palette.roles;
            } catch (error) {}
        }
    }
    FileView {
        id: fontFile
        path: theme.fontPath
        watchChanges: true
        onFileChanged: reload()
        onTextChanged: {
            const font = text().match(/^font_family\s+(.+)$/m);
            if (font) theme.fontFamily = font[1].trim();
            const size = text().match(/^font_size\s+([\d.]+)$/m);
            if (size) theme.fontSize = Math.max(8, Math.min(24, Math.round(Number(size[1]))));
        }
    }
}

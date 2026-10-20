import QtQuick

Item {
    id: tree
    property var rows: []
    property color foreground: "#eeeeee"
    readonly property var drawing: layoutRows()

    function layoutRows() {
        const cells = [];
        let left = Infinity, right = -1, top = Infinity, bottom = -1;
        for (let row = 0; row < rows.length; row++) {
            let column = 0;
            for (const span of rows[row]) {
                for (const glyph of span.text) {
                    if (glyph.trim()) {
                        cells.push({column: column, row: row, glyph: glyph, color: span.color || ""});
                        left = Math.min(left, column);
                        right = Math.max(right, column);
                        top = Math.min(top, row);
                        bottom = Math.max(bottom, row);
                    }
                    column++;
                }
            }
        }
        return {cells: cells, left: left, top: top,
            columns: cells.length ? right - left + 1 : 0,
            lines: cells.length ? bottom - top + 1 : 0};
    }

    onDrawingChanged: if (visible) canvas.requestPaint()
    onForegroundChanged: if (visible) canvas.requestPaint()
    onVisibleChanged: if (visible) canvas.requestPaint()

    Canvas {
        id: canvas
        objectName: "questline-tree-canvas"
        anchors.fill: parent
        // Rasteriza las ramas en una sola textura para evitar los lotes de texto que fallan en Qt.
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);
            const drawing = tree.drawing;
            if (!drawing.cells.length || width <= 16 || height <= 16) return;
            ctx.font = "28px monospace";
            ctx.textBaseline = "top";
            const advance = ctx.measureText("M").width;
            const lineHeight = 35;
            const contentWidth = drawing.columns * advance;
            const contentHeight = drawing.lines * lineHeight;
            const scale = Math.min(1, (width - 16) / contentWidth, (height - 16) / contentHeight);
            ctx.translate((width - contentWidth * scale) / 2, (height - contentHeight * scale) / 2);
            ctx.scale(scale, scale);
            for (const cell of drawing.cells) {
                ctx.fillStyle = cell.color || tree.foreground;
                ctx.fillText(cell.glyph, (cell.column - drawing.left) * advance, (cell.row - drawing.top) * lineHeight);
            }
        }
    }
}

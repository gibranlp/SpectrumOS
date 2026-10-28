pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: backdrop
    property bool horizontal: true
    property var groups: []
    property color surfaceColor: "#232029"
    property int padding: 10
    property real joinRadius: Math.max(0, ((horizontal ? height : width) - frameThickness) / 2)
    property int frameThickness: 8
    readonly property real extent: horizontal ? width : height
    readonly property var segments: mergeGroups(groups, extent)
    ListModel { id: islandModel }
    onSegmentsChanged: syncSegments()
    Component.onCompleted: syncSegments()

    // Conserva las superficies y sus curvas pintadas cuando cambia el título de la ventana.
    function syncSegments(): void {
        for (let index = 0; index < segments.length; index++) {
            const row = { segmentStart: segments[index].start, segmentEnd: segments[index].end };
            if (index < islandModel.count)
                islandModel.set(index, row);
            else
                islandModel.append(row);
        }
        if (islandModel.count > segments.length)
            islandModel.remove(segments.length, islandModel.count - segments.length);
    }

    // Junta grupos cercanos para que sus hombros no se encimen cuando cambia el contenido.
    function mergeGroups(values, limit): var {
        const ranges = values.filter(group => group.visible !== false && group.length > 0)
            .map(group => ({ start: Math.max(0, group.start - padding),
                end: Math.min(limit, group.start + group.length + padding) }))
            .filter(group => group.end > group.start)
            .sort((a, b) => a.start - b.start);
        const merged = [];
        for (const range of ranges) {
            const last = merged[merged.length - 1];
            if (last && range.start - last.end < 2 * joinRadius + 4)
                last.end = Math.max(last.end, range.end);
            else
                merged.push({ start: range.start, end: range.end });
        }
        return merged;
    }

    function maskRect(index): rect {
        const segment = segments[index];
        if (!segment)
            return Qt.rect(0, 0, 0, 0);
        const start = Math.max(0, Math.floor(segment.start - joinRadius));
        const end = Math.min(extent, Math.ceil(segment.end + joinRadius));
        return horizontal ? Qt.rect(start, 0, end - start, height) : Qt.rect(0, start, width, end - start);
    }

    Repeater {
        model: islandModel
        Canvas {
            id: island
            required property real segmentStart
            required property real segmentEnd
            objectName: "barIsland"
            x: backdrop.horizontal ? segmentStart - shoulder : 0
            y: backdrop.horizontal ? 0 : segmentStart - shoulder
            width: backdrop.horizontal ? span : backdrop.width
            height: backdrop.horizontal ? backdrop.height : span
            readonly property real shoulder: backdrop.joinRadius
            readonly property real span: segmentEnd - segmentStart + 2 * shoulder
            readonly property real depth: backdrop.horizontal ? backdrop.height : backdrop.width
            readonly property real tipRadius: Math.min(shoulder, (segmentEnd - segmentStart) / 2)
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onShoulderChanged: requestPaint()
            onTipRadiusChanged: requestPaint()
            onDepthChanged: requestPaint()
            Connections {
                target: backdrop
                function onSurfaceColorChanged() { island.requestPaint(); }
                function onFrameThicknessChanged() { island.requestPaint(); }
                function onHorizontalChanged() { island.requestPaint(); }
            }
            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.save();
                // Intercambia los ejes para conservar el mismo contorno en la barra superior.
                if (backdrop.horizontal) ctx.transform(0, 1, 1, 0, 0, 0);
                const frame = backdrop.frameThickness;
                const start = shoulder;
                const end = span - shoulder;
                const bend = depth - tipRadius;
                const k = 0.5522847498;
                // Dos cuartos de círculo se unen con la misma tangente, sin un tramo recto entre ellos.
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.lineTo(frame, 0);
                ctx.bezierCurveTo(frame, start * k, bend - (bend - frame) * k, start, bend, start);
                ctx.bezierCurveTo(bend + tipRadius * k, start, depth, start + tipRadius * (1 - k), depth, start + tipRadius);
                ctx.lineTo(depth, end - tipRadius);
                ctx.bezierCurveTo(depth, end - tipRadius * (1 - k), bend + tipRadius * k, end, bend, end);
                ctx.bezierCurveTo(bend - (bend - frame) * k, end, frame, end + shoulder * (1 - k), frame, span);
                ctx.lineTo(0, span);
                ctx.closePath();
                ctx.fillStyle = backdrop.surfaceColor;
                ctx.fill();
                ctx.restore();
            }
        }
    }
}

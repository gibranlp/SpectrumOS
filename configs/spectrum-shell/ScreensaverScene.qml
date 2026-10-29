import QtQuick

Item {
    id: scene
    required property var colors
    property bool running: false
    property real elapsed: 0
    readonly property int targetFps: 60
    readonly property int glyphCell: 12
    readonly property int glyphFontSize: 10
    readonly property string glyphs: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉ"
    readonly property bool gpuMatrix: GraphicsInfo.api !== GraphicsInfo.Software && matrixEffect.status !== ShaderEffect.Error && matrixGlyphs.status !== Image.Error
    property int frameCount: 0
    property int paintedFrames: 0
    property real paintBudget: 0

    function reset(): void {
        elapsed = 0;
        frameCount = 0;
        paintedFrames = 0;
        paintBudget = 0;
        canvas.requestPaint();
    }
    function advance(seconds): void {
        if (!running || !visible) return;
        const delta = Math.max(0, Math.min(0.1, seconds));
        elapsed += delta;
        paintBudget += delta;
        if (paintBudget + 0.000001 >= 1 / targetFps) {
            paintBudget = Math.max(0, paintBudget - 1 / targetFps) % (1 / targetFps);
            frameCount++;
            if (!gpuMatrix) canvas.requestPaint();
        }
    }
    function hash(value): real {
        const number = Math.sin(value * 127.1 + 311.7) * 43758.5453;
        return number - Math.floor(number);
    }
    onRunningChanged: if (running) reset()
    onColorsChanged: { glyphAtlas.ready = false; glyphAtlas.requestPaint(); canvas.requestPaint(); }

    // Solo se rasteriza el alfabeto; los símbolos, las estelas y los destellos cambian en la GPU.
    Canvas {
        id: glyphAtlas
        objectName: "screensaver-glyph-atlas"
        width: scene.glyphs.length * scene.glyphCell
        height: scene.glyphCell * 3
        opacity: 0
        property bool ready: false
        property int builds: 0
        renderStrategy: Canvas.Immediate
        onAvailableChanged: if (available) requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.font = scene.glyphFontSize + "px monospace";
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            const palette = [scene.colors.accent, scene.colors.accent_alt || scene.colors.accent, scene.colors.foreground];
            for (let tone = 0; tone < palette.length; tone++) {
                ctx.fillStyle = palette[tone];
                for (let glyph = 0; glyph < scene.glyphs.length; glyph++)
                    ctx.fillText(scene.glyphs[glyph], (glyph + 0.5) * scene.glyphCell, (tone + 0.5) * scene.glyphCell);
            }
            builds++;
        }
        onPainted: { ready = true; glyphTexture.scheduleUpdate(); canvas.requestPaint(); }
    }
    Rectangle { anchors.fill: parent; color: scene.colors.background }
    Rectangle { anchors.fill: parent; color: "#59000000" }
    ShaderEffectSource {
        id: glyphTexture
        sourceItem: glyphAtlas
        hideSource: true
        live: false
        visible: false
        textureSize: Qt.size(glyphAtlas.width, glyphAtlas.height)
        smooth: false
    }
    Image {
        id: matrixGlyphs
        objectName: "screensaver-matrix-glyphs"
        source: "matrix-code-msdf.png"
        visible: false
        smooth: true
        mipmap: true
    }
    ShaderEffect {
        id: matrixEffect
        objectName: "screensaver-matrix-effect"
        anchors.fill: parent
        visible: scene.gpuMatrix && matrixGlyphs.status === Image.Ready
        property var atlas: matrixGlyphs
        property size fieldSize: Qt.size(canvas.width, canvas.height)
        property real elapsed: scene.elapsed
        property real glyphCell: scene.glyphCell
        property color accentColor: scene.colors.accent
        property color secondaryColor: scene.colors.accent_alt || scene.colors.accent
        property color headColor: scene.colors.foreground
        fragmentShader: "screensaver-matrix.frag.qsb"
    }
    Canvas {
        id: canvas
        objectName: "screensaver-canvas"
        width: Math.min(scene.width, 1280)
        height: scene.height * width / Math.max(1, scene.width)
        scale: scene.width / Math.max(1, width)
        transformOrigin: Item.TopLeft
        visible: !scene.gpuMatrix
        renderStrategy: Canvas.Threaded
        onPainted: scene.paintedFrames++
        onPaint: {
            if (!glyphAtlas.ready) return;
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const cell = scene.glyphCell;
            for (let column = 0; column < Math.ceil(width / cell); column++) {
                const seed = scene.hash(column + 1);
                const length = 12 + Math.floor(scene.hash(column + 17) * 23);
                const speed = 5 + scene.hash(column + 43) * 10;
                const span = height / cell + length + 14;
                const travel = scene.elapsed * speed + seed * span;
                const head = travel % span - 7;
                const cycle = Math.floor(travel / span);
                for (let row = Math.max(0, Math.ceil(head - length)); row < Math.min(height / cell, head); row++) {
                    const distance = head - row;
                    const rate = 2 + scene.hash(column * 17 + row) * 7;
                    const tick = Math.floor(scene.elapsed * rate);
                    const glyph = Math.floor(scene.hash(column * 139 + row * 37 + tick * 13 + cycle) * scene.glyphs.length);
                    const tone = distance < 1.3 ? 2 : seed > 0.75 ? 1 : 0;
                    ctx.globalAlpha = distance < 1.3 ? 1 : Math.pow(1 - distance / length, 1.2) * 0.8;
                    ctx.drawImage(glyphAtlas, glyph * cell, tone * cell, cell, cell,
                        column * cell, row * cell, cell, cell);
                }
            }
            ctx.globalAlpha = 1;
        }
    }
    FrameAnimation {
        objectName: "screensaver-clock"
        running: scene.running && scene.visible
        onTriggered: scene.advance(frameTime)
    }
}

import QtQuick

Item {
    id: scene
    required property var colors
    property string effect: "matrix"
    property string branding: "alternate"
    property var masks: ({wordmark: {points: [], aspect: 6}, logo: {points: [], aspect: 1}})
    property bool running: false
    property real elapsed: 0
    readonly property real cycleDuration: 14
    readonly property int targetFps: 60
    readonly property string currentEffect: effect === "cycle" ? ["matrix", "rain", "constellation"][Math.floor(elapsed / (cycleDuration * 2)) % 3] : effect
    readonly property string currentBranding: branding === "alternate" ? (Math.floor(elapsed / cycleDuration) % 2 ? "logo" : "wordmark") : branding
    readonly property real formation: {
        const phase = elapsed % cycleDuration;
        return phase < 2.5 ? 0 : phase < 5.5 ? (phase - 2.5) / 3 : phase < 10 ? 1 : Math.max(0, 1 - (phase - 10) / 3);
    }
    readonly property var targetMask: masks[currentBranding] && masks[currentBranding].points.length ? masks[currentBranding] : masks.wordmark
    property int frameCount: 0
    property var particles: []
    property real paintBudget: 0
    property int paintedFrames: 0
    readonly property string glyphs: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZｱｲｳｴｵｶｷｸｹｺ"

    function reset(): void {
        elapsed = 0;
        frameCount = 0;
        paintBudget = 0;
        paintedFrames = 0;
        particles = Array.from({length: 700}, (_, index) => ({
            x: Math.random(), y: Math.random(), speed: 0.11 + Math.random() * 0.22,
            offset: Math.random() * Math.PI * 2, glyph: index % 37
        }));
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
            canvas.requestPaint();
        }
    }
    onRunningChanged: if (running) reset()
    onColorsChanged: { glyphAtlas.ready = false; glyphAtlas.requestPaint(); canvas.requestPaint(); }
    onEffectChanged: if (running) reset()
    onBrandingChanged: if (running) reset()

    function drawGlyph(context, glyph, tone, x, y): void {
        if (glyphAtlas.ready)
            context.drawImage(glyphAtlas, glyph * 16, tone * 16, 16, 16, x - 8, y - 8, 16, 16);
        else
            context.fillText(glyphs[glyph], x, y);
    }

    // El atlas reutiliza los glifos de cada paleta sin volver a rasterizar texto en cada cuadro.
    Canvas {
        id: glyphAtlas
        objectName: "screensaver-glyph-atlas"
        width: scene.glyphs.length * 16
        height: 48
        opacity: 0
        property bool ready: false
        renderStrategy: Canvas.Immediate
        onAvailableChanged: if (available) requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.font = "12px monospace";
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            const palette = [scene.colors.accent, scene.colors.accent_alt || scene.colors.accent, scene.colors.foreground];
            for (let tone = 0; tone < palette.length; tone++) {
                ctx.fillStyle = palette[tone];
                for (let glyph = 0; glyph < scene.glyphs.length; glyph++)
                    ctx.fillText(scene.glyphs[glyph], glyph * 16 + 8, tone * 16 + 8);
            }
        }
        onPainted: { ready = true; canvas.requestPaint(); }
    }

    Canvas {
        id: canvas
        objectName: "screensaver-canvas"
        width: Math.min(scene.width, 1280)
        height: scene.height * width / Math.max(1, scene.width)
        scale: scene.width / Math.max(1, width)
        transformOrigin: Item.TopLeft
        renderStrategy: Canvas.Threaded
        onPainted: scene.paintedFrames++
        onPaint: {
            const ctx = getContext("2d");
            ctx.globalAlpha = 1;
            ctx.fillStyle = scene.colors.background;
            ctx.fillRect(0, 0, width, height);
            ctx.fillStyle = "rgba(0,0,0,0.35)";
            ctx.fillRect(0, 0, width, height);
            const palette = [scene.colors.accent, scene.colors.accent_alt || scene.colors.accent, scene.colors.foreground];
            const matrix = scene.currentEffect === "matrix";
            const rain = scene.currentEffect === "rain";
            const mask = scene.targetMask;
            const targetWidth = Math.min(width * (scene.currentBranding === "logo" ? 0.32 : 0.76), height * (scene.currentBranding === "logo" ? 0.55 * mask.aspect : 2.7));
            const targetHeight = targetWidth / mask.aspect;
            const originX = (width - targetWidth) / 2 + Math.sin(scene.elapsed / 14) * width * 0.015;
            const originY = (height - targetHeight) / 2 + Math.cos(scene.elapsed / 17) * height * 0.025;
            const gathering = scene.formation * scene.formation * (3 - 2 * scene.formation);
            ctx.font = "12px monospace";
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            const limit = Math.min(scene.particles.length, mask.points.length || 200);
            for (let index = 0; index < limit; index++) {
                const p = scene.particles[index];
                const dropY = (p.y + scene.elapsed * p.speed) % 1;
                const freeX = matrix ? (Math.floor(p.x * width / 20) + 0.5) * 20 / width
                    : rain ? (p.x - scene.elapsed * 0.045 + 10) % 1 : p.x;
                let x = freeX * width;
                let y = dropY * height;
                if (!matrix && !rain) {
                    x = width / 2 + Math.cos(p.offset + scene.elapsed * p.speed * 1.6) * width * (0.15 + p.x * 0.42);
                    y = height / 2 + Math.sin(p.offset + scene.elapsed * p.speed * 1.6) * height * (0.15 + p.y * 0.42);
                }
                const target = mask.points[index];
                const ambient = index % 5 === 0;
                const blend = ambient ? gathering * 0.08 : gathering;
                if (target) {
                    const ripple = Math.sin(scene.elapsed * 2.1 + p.offset);
                    x += (originX + target[0] * targetWidth + ripple * 1.8 - x) * blend;
                    y += (originY + target[1] * targetHeight + Math.cos(scene.elapsed * 1.7 + p.offset) * 2.2 - y) * blend;
                }
                if (rain) {
                    ctx.strokeStyle = palette[index % palette.length];
                    ctx.globalAlpha = 0.3 + blend * 0.7;
                } else if (!matrix || !glyphAtlas.ready) {
                    ctx.fillStyle = palette[index % palette.length];
                }
                if (matrix) {
                    if (index % 6 === 0 && blend < 0.85) {
                        for (let tail = 1; tail <= 4; tail++) {
                            ctx.globalAlpha = (1 - blend) * (1 - tail / 5) * 0.24;
                            scene.drawGlyph(ctx, (p.glyph + tail + Math.floor(scene.elapsed * 9)) % scene.glyphs.length, index % palette.length, x, y - tail * 17);
                        }
                    }
                    ctx.globalAlpha = 0.48 + blend * 0.52;
                    scene.drawGlyph(ctx, (p.glyph + Math.floor(scene.elapsed * 6)) % scene.glyphs.length, index % palette.length, x, y);
                } else if (rain) {
                    ctx.lineWidth = 1.3 + blend;
                    ctx.beginPath();
                    ctx.moveTo(x, y);
                    ctx.lineTo(x + 3 * (1 - blend), y - 10 * (1 - blend) - 2);
                    ctx.stroke();
                } else {
                    ctx.globalAlpha = 0.45 + blend * 0.5 + Math.sin(scene.elapsed * 2 + p.offset) * 0.05;
                    ctx.beginPath();
                    ctx.arc(x, y, 1.3 + blend * 0.5, 0, Math.PI * 2);
                    ctx.fill();
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

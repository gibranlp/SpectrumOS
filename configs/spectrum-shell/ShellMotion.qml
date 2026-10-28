import QtQuick

Translate {
    id: motion
    required property Item surface
    required property bool expanded
    required property string edge
    required property real viewportWidth
    required property real viewportHeight
    property bool bounceEnabled: true
    property bool animationsEnabled: true
    onAnimationsEnabledChanged: if (ready) animate()
    property int duration: 300
    property real progress: 0
    property real phase: 0
    property real startProgress: 0
    property real destination: 0
    readonly property real overshoot: openingOvershoot(travelDistance)
    property bool bouncing: false
    property bool ready: false
    readonly property bool active: expanded || animation.running || progress > 0
    property ShellGeometry geometry: ShellGeometry {}
    readonly property real overhang: Math.max(geometry.frameThickness + geometry.curveRadius, surface.joinRadius || 0)

    readonly property real travelDistance: edge === "left" ? surface.x + surface.width + overhang
        : edge === "right" ? viewportWidth - surface.x + overhang
        : edge === "top" ? surface.y + surface.height + overhang
        : viewportHeight - surface.y + overhang

    // El rebote llega a unos cinco píxeles, sin crecer con el tamaño del panel.
    function openingOvershoot(distance): real {
        const fraction = Math.min(5, distance * 0.025) / Math.max(1, distance);
        let low = 0, high = 2;
        for (let i = 0; i < 18; i++) {
            const value = (low + high) / 2;
            const peak = 4 * value * value * value / (27 * (value + 1) * (value + 1));
            if (peak < fraction) low = value;
            else high = value;
        }
        return (low + high) / 2;
    }

    // El destino no se anima: sólo se desplaza la superficie desde su borde.
    x: edge === "left" ? -(surface.x + surface.width + overhang) * (1 - progress)
        : edge === "right" ? (viewportWidth - surface.x + overhang) * (1 - progress) : 0
    y: edge === "top" ? -(surface.y + surface.height + overhang) * (1 - progress)
        : edge === "bottom" ? (viewportHeight - surface.y + overhang) * (1 - progress) : 0

    Component.onCompleted: {
        ready = true;
        Qt.callLater(animate);
    }
    onExpandedChanged: {
        if (ready)
            Qt.callLater(animate);
    }

    // La ventana recibe su tamaño al mostrarse; la curva usa esa geometría durante toda la apertura.
    onPhaseChanged: {
        const remaining = phase - 1;
        const eased = bouncing ? 1 + (overshoot + 1) * remaining * remaining * remaining
            + overshoot * remaining * remaining : 1 + remaining * remaining * remaining;
        progress = startProgress + (destination - startProgress) * eased;
    }

    function animate(): void {
        animation.stop();
        const next = expanded ? 1 : 0;
        if (!animationsEnabled) {
            progress = next;
            return;
        }
        if (progress === next)
            return;
        startProgress = progress;
        destination = next;
        bouncing = expanded && bounceEnabled;
        phase = 0;
        animation.duration = duration + (bouncing ? 80 : 0);
        animation.start();
    }

    property NumberAnimation animation: NumberAnimation {
        target: motion
        property: "phase"
        from: 0
        to: 1
        easing.type: Easing.Linear
    }
}

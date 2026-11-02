import Spectrum.Igor 1.0 as Runtime

Runtime.IgorStage {
    id: host
    motionProgress: revealMotion.progress
    motionActive: revealMotion.active
    revealMotion: ShellMotion {
        objectName: "igorRevealMotion"
        surface: host.motionSurface
        animationsEnabled: host.animationsEnabled
        bounceEnabled: false
        expanded: host.visiting
        edge: host.edge
        viewportWidth: host.motionViewportWidth
        viewportHeight: host.motionViewportHeight
        duration: host.animationDuration
    }
}

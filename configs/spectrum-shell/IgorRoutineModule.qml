import Spectrum.Igor 1.0 as Runtime
import Spectrum.Igor.Desktop 1.0 as Desktop

Runtime.IgorRoutine {
    readonly property var wardrobe: wardrobeState
    Desktop.WardrobeState { id: wardrobeState }
    readonly property string runtimeVersion: Runtime.RuntimeInfo.version
    readonly property int apiVersion: Runtime.RuntimeInfo.apiVersion
}

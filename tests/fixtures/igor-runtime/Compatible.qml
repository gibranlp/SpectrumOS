import Spectrum.Igor 1.0 as Runtime

Runtime.IgorRoutine {
    readonly property string runtimeVersion: Runtime.RuntimeInfo.version
    readonly property int apiVersion: Runtime.RuntimeInfo.apiVersion
}

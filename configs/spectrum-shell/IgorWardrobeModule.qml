import Spectrum.Igor 1.0 as Runtime

Runtime.IgorWardrobe {
    required property var theme
    property bool active: false
    store: theme.igorWardrobe
    colors: theme.colors
    fontFamily: theme.fontFamily
    fontSize: theme.fontSize
    previewActive: active
    animationsEnabled: theme.animationsEnabled !== false
}

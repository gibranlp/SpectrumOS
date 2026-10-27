import QtQuick
import QtQuick.Controls

ComboBox {
    id: choice
    required property var theme
    property bool translateModel: false
    displayText: translateModel ? qsTranslate("Spectrum", currentText) : currentText
    delegate: ItemDelegate {
        required property int index
        width: choice.width
        text: choice.translateModel ? qsTranslate("Spectrum", choice.textAt(index)) : choice.textAt(index)
        font: choice.font
        highlighted: choice.highlightedIndex === index
    }
    implicitHeight: 34
    font { family: theme.fontFamily; pixelSize: theme.fontSize }
    palette {
        button: choice.theme.colors.surface_alt
        buttonText: choice.theme.colors.foreground
        base: choice.theme.colors.surface_alt
        text: choice.theme.colors.foreground
        window: choice.theme.colors.surface_alt
        windowText: choice.theme.colors.foreground
        highlight: choice.theme.colors.accent
        highlightedText: choice.theme.colors.background
    }
    background: Rectangle {
        radius: 8
        color: choice.activeFocus ? choice.theme.colors.accent : choice.theme.colors.surface_alt
        opacity: choice.enabled ? 1 : 0.65
    }
    contentItem: Text {
        leftPadding: 10
        rightPadding: 28
        text: choice.displayText
        font: choice.font
        color: choice.activeFocus ? choice.theme.colors.background : choice.theme.colors.foreground
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}

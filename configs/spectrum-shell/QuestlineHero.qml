import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: heroView
    required property var theme
    property var hero: null
    readonly property var profile: hero || ({})
    readonly property var powers: profile.powers || []
    readonly property var unlockedPowers: powers.filter(power => power.unlocked)
    readonly property var nextPower: powers.find(power => !power.unlocked) || null
    readonly property bool maximumLevel: (profile.level || 1) >= 100
    readonly property real progress: maximumLevel ? 1 : profile.xp_next_level > 0 ? Math.max(0, Math.min(1, (profile.xp || 0) / profile.xp_next_level)) : 0
    spacing: 14

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: header.implicitHeight + 40
        radius: 16
        color: heroView.theme.colors.background
        RowLayout {
            id: header
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            spacing: 28
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: heroView.profile.username || qsTranslate("Spectrum", "Your hero")
                    wrapMode: Text.Wrap
                    color: heroView.theme.colors.foreground
                    font { family: heroView.theme.fontFamily; pixelSize: heroView.theme.fontSize + 18; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: (heroView.profile.class || qsTranslate("Spectrum", "Class unavailable")) + (heroView.profile.title ? " · " + heroView.profile.title : "")
                    wrapMode: Text.Wrap
                    color: heroView.theme.colors.accent
                    font { family: heroView.theme.fontFamily; pixelSize: heroView.theme.fontSize + 3; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: heroView.profile.description || qsTranslate("Spectrum", "Your Questline character and class progression.")
                    wrapMode: Text.Wrap
                    color: heroView.theme.colors.muted
                    font { family: heroView.theme.fontFamily; pixelSize: heroView.theme.fontSize }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 12
                    radius: 6
                    color: heroView.theme.colors.surface_alt
                    Rectangle {
                        width: parent.width * heroView.progress
                        height: parent.height
                        radius: 6
                        color: heroView.theme.colors.accent
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: heroView.maximumLevel ? qsTranslate("Spectrum", "Maximum level · ") + (heroView.profile.xp || 0) + qsTranslate("Spectrum", " XP")
                        : heroView.profile.xp_next_level > 0 ? (heroView.profile.xp || 0) + " / " + heroView.profile.xp_next_level + qsTranslate("Spectrum", " XP · ") + Math.max(0, heroView.profile.xp_next_level - (heroView.profile.xp || 0)) + qsTranslate("Spectrum", " XP to level ") + ((heroView.profile.level || 1) + 1)
                        : (heroView.profile.xp || 0) + qsTranslate("Spectrum", " XP")
                    wrapMode: Text.Wrap
                    color: heroView.theme.colors.foreground
                    font { family: heroView.theme.fontFamily; pixelSize: heroView.theme.fontSize }
                }
            }
            ColumnLayout {
                Layout.preferredWidth: 180
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTranslate("Spectrum", "LEVEL")
                    color: heroView.theme.colors.muted
                    font { family: heroView.theme.fontFamily; pixelSize: heroView.theme.fontSize; bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: heroView.profile.level || "—"
                    color: heroView.theme.colors.accent
                    font { family: heroView.theme.fontFamily; pixelSize: 76; bold: true }
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 14
        Rectangle {
            Layout.preferredWidth: 410
            Layout.fillHeight: true
            radius: 16
            color: heroView.theme.colors.background
            Flickable {
                anchors { fill: parent; margins: 16 }
                clip: true
                contentWidth: width
                contentHeight: details.implicitHeight
                ColumnLayout {
                    id: details
                    width: parent.width
                    spacing: 16
                    Repeater {
                        model: [
                            { title: qsTranslate("Spectrum", "Class passive"), body: heroView.profile.passive || qsTranslate("Spectrum", "Class details are unavailable in this Questline version.") },
                            { title: qsTranslate("Spectrum", "Specialization"), body: heroView.profile.specialization || ((heroView.profile.level || 1) < 10 ? qsTranslate("Spectrum", "Unlocks at level 10") : qsTranslate("Spectrum", "Choose your specialization in Questline")) },
                            { title: qsTranslate("Spectrum", "Next power"), body: heroView.nextPower ? qsTranslate("Spectrum", "Level ") + heroView.nextPower.level + " · " + heroView.nextPower.name + "\n" + heroView.nextPower.description : heroView.powers.length ? qsTranslate("Spectrum", "All class powers unlocked") : qsTranslate("Spectrum", "Class powers unavailable") },
                            { title: qsTranslate("Spectrum", "Adventure"), body: (heroView.profile.tasks_completed === undefined ? "" : heroView.profile.tasks_completed + qsTranslate("Spectrum", " tasks completed\n"))
                                + (heroView.profile.scrolls_written === undefined ? "" : heroView.profile.scrolls_written + qsTranslate("Spectrum", " scrolls written\n"))
                                + (heroView.profile.current_streak === undefined ? "" : heroView.profile.current_streak + qsTranslate("Spectrum", " day streak · Best ") + heroView.profile.best_streak + "\n")
                                + (heroView.profile.created_at ? qsTranslate("Spectrum", "Hero since ") + heroView.profile.created_at.slice(0, 10) : "") },
                            { title: heroView.profile.order || qsTranslate("Spectrum", "Class"), body: heroView.profile.flavor || "" }
                        ]
                        ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            visible: !!modelData.body
                            spacing: 7
                            Text {
                                Layout.fillWidth: true
                                text: modelData.title
                                color: heroView.theme.colors.foreground
                                font { family: heroView.theme.fontFamily; pixelSize: heroView.theme.fontSize + 2; bold: true }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.body
                                wrapMode: Text.Wrap
                                color: heroView.theme.colors.muted
                                font { family: heroView.theme.fontFamily; pixelSize: heroView.theme.fontSize }
                            }
                        }
                    }
                    Repeater {
                        model: heroView.profile.specializations || []
                        Text {
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData.name + (heroView.profile.specialization === modelData.name ? qsTranslate("Spectrum", " · Selected") : "") + "\n" + modelData.description
                            wrapMode: Text.Wrap
                            color: heroView.profile.specialization === modelData.name ? heroView.theme.colors.accent : heroView.theme.colors.muted
                            font { family: heroView.theme.fontFamily; pixelSize: heroView.theme.fontSize }
                        }
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 16
            color: heroView.theme.colors.background
            ColumnLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 12
                Text {
                    Layout.fillWidth: true
                    text: qsTranslate("Spectrum", "Class powers · ") + heroView.unlockedPowers.length + " / " + heroView.powers.length + qsTranslate("Spectrum", " unlocked")
                    color: heroView.theme.colors.foreground
                    font { family: heroView.theme.fontFamily; pixelSize: heroView.theme.fontSize + 2; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    visible: heroView.powers.length === 0
                    text: qsTranslate("Spectrum", "Class progression details are unavailable in this Questline version.")
                    wrapMode: Text.Wrap
                    color: heroView.theme.colors.muted
                    font { family: heroView.theme.fontFamily; pixelSize: heroView.theme.fontSize }
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: heroView.powers
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: powerContent.implicitHeight + 24
                        radius: 10
                        color: heroView.theme.colors.surface_alt
                        ColumnLayout {
                            id: powerContent
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                            spacing: 6
                            Text {
                                Layout.fillWidth: true
                                text: qsTranslate("Spectrum", "Level ") + modelData.level + " · " + modelData.name + (modelData.unlocked ? qsTranslate("Spectrum", " · Unlocked") : qsTranslate("Spectrum", " · Locked"))
                                wrapMode: Text.Wrap
                                color: modelData.unlocked ? heroView.theme.colors.accent : heroView.theme.colors.muted
                                font { family: heroView.theme.fontFamily; pixelSize: heroView.theme.fontSize + 1; bold: true }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.description
                                wrapMode: Text.Wrap
                                color: heroView.theme.colors.foreground
                                font { family: heroView.theme.fontFamily; pixelSize: heroView.theme.fontSize }
                            }
                        }
                    }
                }
            }
        }
    }
}

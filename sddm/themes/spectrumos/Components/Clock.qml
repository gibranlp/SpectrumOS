//
// This file is part of Sugar Dark, a theme for the Simple Display Desktop Manager.
//
// Copyright 2018 Marian Arlt
//
// Sugar Dark is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Sugar Dark is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Sugar Dark. If not, see <https://www.gnu.org/licenses/>.
//

import QtQuick 2.11
import QtQuick.Controls 2.4


Column {
    id: clock
    spacing: 0
    width: parent.width / 2

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2
        visible: config.HeaderText !== ""
        
        Label {
            text: "¡"
            color: colors.color7
            font.pointSize: root.font.pointSize * 3
            renderType: Text.QtRendering
        }
        Label {
            text: "S"
            color: colors.color1
            font.pointSize: root.font.pointSize * 3
            renderType: Text.QtRendering
        }
        Label {
            text: "p"
            color: colors.color2
            font.pointSize: root.font.pointSize * 3
            renderType: Text.QtRendering
        }
        Label {
            text: "e"
            color: colors.color3
            font.pointSize: root.font.pointSize * 3
            renderType: Text.QtRendering
        }
        Label {
            text: "c"
            color: colors.color4
            font.pointSize: root.font.pointSize * 3
            renderType: Text.QtRendering
        }
        Label {
            text: "t"
            color: colors.color5
            font.pointSize: root.font.pointSize * 3
            renderType: Text.QtRendering
        }
        Label {
            text: "r"
            color: colors.color6
            font.pointSize: root.font.pointSize * 3
            renderType: Text.QtRendering
        }
        Label {
            text: "u"
            color: colors.color1
            font.pointSize: root.font.pointSize * 3
            renderType: Text.QtRendering
        }
        Label {
            text: "m"
            color: colors.color2
            font.pointSize: root.font.pointSize * 3
            renderType: Text.QtRendering
        }
        Label {
            text: "O"
            color: colors.color3
            font.pointSize: root.font.pointSize * 3
            renderType: Text.QtRendering
        }
        Label {
            text: "S"
            color: colors.color4
            font.pointSize: root.font.pointSize * 3
            renderType: Text.QtRendering
        }
        Label {
            text: "!"
            color: colors.color7
            font.pointSize: root.font.pointSize * 3
            renderType: Text.QtRendering
        }
    }

    Label {
        id: timeLabel
        anchors.horizontalCenter: parent.horizontalCenter
        font.pointSize: root.font.pointSize * 3
        color: colors.color1
        renderType: Text.QtRendering
        function updateTime() {
            text = new Date().toLocaleTimeString(Qt.locale(config.Locale), config.HourFormat == "long" ? Locale.LongFormat : config.HourFormat !== "" ? config.HourFormat : Locale.ShortFormat)
        }
    }

    Label {
        id: dateLabel
        anchors.horizontalCenter: parent.horizontalCenter
        color: colors.color4
        renderType: Text.QtRendering
        function updateTime() {
            text = new Date().toLocaleDateString(Qt.locale(config.Locale), config.DateFormat == "short" ? Locale.ShortFormat : config.DateFormat !== "" ? config.DateFormat : Locale.LongFormat)
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            dateLabel.updateTime()
            timeLabel.updateTime()
        }
    }

    Component.onCompleted: {
        dateLabel.updateTime()
        timeLabel.updateTime()
    }
}

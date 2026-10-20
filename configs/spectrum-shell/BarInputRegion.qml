pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Region {
    id: region
    required property var backdrop
    property var hoverTarget: null
    property bool islands: true
    width: islands ? 0 : backdrop.width
    height: islands ? 0 : backdrop.height
    readonly property rect first: islands ? backdrop.maskRect(0) : Qt.rect(0, 0, 0, 0)
    readonly property rect second: islands ? backdrop.maskRect(1) : Qt.rect(0, 0, 0, 0)
    readonly property rect third: islands ? backdrop.maskRect(2) : Qt.rect(0, 0, 0, 0)
    readonly property rect fourth: islands ? backdrop.maskRect(3) : Qt.rect(0, 0, 0, 0)
    readonly property rect fifth: islands ? backdrop.maskRect(4) : Qt.rect(0, 0, 0, 0)
    readonly property rect sixth: islands ? backdrop.maskRect(5) : Qt.rect(0, 0, 0, 0)
    Region { x: region.first.x; y: region.first.y; width: region.first.width; height: region.first.height }
    Region { x: region.second.x; y: region.second.y; width: region.second.width; height: region.second.height }
    Region { x: region.third.x; y: region.third.y; width: region.third.width; height: region.third.height }
    Region { x: region.fourth.x; y: region.fourth.y; width: region.fourth.width; height: region.fourth.height }
    Region { x: region.fifth.x; y: region.fifth.y; width: region.fifth.width; height: region.fifth.height }
    Region { x: region.sixth.x; y: region.sixth.y; width: region.sixth.width; height: region.sixth.height }
    Region { item: region.hoverTarget }
}

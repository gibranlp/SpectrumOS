import QtQuick
import QtQuick.Window

Item {
    id: navigation
    property Item target: parent
    readonly property var window: target.Window.window
    readonly property var focusedItem: window ? window.activeFocusItem : null

    readonly property bool textFocused: focusedItem !== null && contains(focusedItem) && focusedItem.cursorPosition !== undefined

    Rectangle {
        objectName: "keyboard-input-focus-outline"
        parent: navigation.textFocused ? navigation.focusedItem : navigation
        anchors.fill: parent
        visible: navigation.textFocused
        color: "transparent"
        border.width: 1
        border.color: {
            for (let item = parent; item; item = item.parent)
                if (item.theme && item.theme.colors) return item.theme.colors.accent;
            return navigation.textFocused ? navigation.focusedItem.color : "transparent";
        }
        radius: 4
    }

    function contains(item): bool {
        for (let node = item; node; node = node.parent)
            if (node === target) return true;
        return false;
    }

    function reveal(item): void {
        if (!contains(item)) return;
        for (let node = item.parent; node && node !== target; node = node.parent) {
            if (node.contentItem === undefined || node.contentY === undefined) continue;
            const point = item.mapToItem(node.contentItem, 0, 0);
            if (point.y < node.contentY)
                node.contentY = Math.max(0, point.y - 4);
            else if (point.y + item.height > node.contentY + node.height)
                node.contentY = Math.min(Math.max(0, node.contentHeight - node.height), point.y + item.height - node.height + 4);
            if (node.contentX !== undefined) {
                if (point.x < node.contentX) node.contentX = Math.max(0, point.x - 4);
                else if (point.x + item.width > node.contentX + node.width)
                    node.contentX = Math.min(Math.max(0, node.contentWidth - node.width), point.x + item.width - node.width + 4);
            }
        }
    }

    function move(forward): void {
        const origin = window.activeFocusItem || target;
        let item = origin.nextItemInFocusChain(forward);
        while (item && item !== origin) {
            if (contains(item) && item.activeFocusOnTab && item.visible && item.enabled) {
                item.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);
                return;
            }
            item = item.nextItemInFocusChain(forward);
        }
    }

    function moveDirection(key): void {
        const origin = window.activeFocusItem;
        if (!origin || origin === target || !contains(origin)) {
            move(true);
            return;
        }
        const horizontal = key === Qt.Key_Left || key === Qt.Key_Right;
        const sign = key === Qt.Key_Left || key === Qt.Key_Up ? -1 : 1;
        const start = origin.mapToItem(target, origin.width / 2, origin.height / 2);
        let best = null;
        let bestScore = Infinity;
        let item = origin.nextItemInFocusChain(true);
        while (item && item !== origin) {
            if (contains(item) && item.activeFocusOnTab && item.visible && item.enabled) {
                const point = item.mapToItem(target, item.width / 2, item.height / 2);
                const distance = sign * (horizontal ? point.x - start.x : point.y - start.y);
                if (distance > 1) {
                    const offset = Math.abs(horizontal ? point.y - start.y : point.x - start.x);
                    const span = horizontal ? (origin.height + item.height) / 2 : (origin.width + item.width) / 2;
                    const score = distance + Math.max(0, offset - span) * 4 + offset * 0.1;
                    if (score < bestScore) { best = item; bestScore = score; }
                }
            }
            item = item.nextItemInFocusChain(true);
        }
        if (best) best.forceActiveFocus(Qt.OtherFocusReason);
    }

    Connections {
        target: navigation.window
        function onActiveFocusItemChanged() { navigation.reveal(navigation.window.activeFocusItem); }
    }
}

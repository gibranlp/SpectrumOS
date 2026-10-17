import QtQuick
import Quickshell.Services.Pipewire
import "MeetingDetection.js" as MeetingDetection

Item {
    id: meeting
    property var links: Pipewire.linkGroups.values
    readonly property var captureLinks: links.filter(link => link.source && link.target
        && link.source.audio && !link.source.isStream && !link.source.isSink
        && link.target.audio && link.target.isStream && !link.target.isSink)
    PwObjectTracker { objects: meeting.captureLinks }
    PwObjectTracker { objects: meeting.captureLinks.reduce((nodes, link) => nodes.concat([link.source, link.target]), []) }
    readonly property bool active: captureLinks.some(link => MeetingDetection.isActiveMicrophoneLink(link, PwLinkState.Active))
}

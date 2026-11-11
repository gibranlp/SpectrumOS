import QtQuick
import Quickshell.Io

QtObject {
    id: sounds
    required property string backendDir

    function play(event): void {
        const player = event === "complete" ? completion : event === "swarm" ? swarm : event === "hydration" ? hydration : opening;
        if (!player.running) player.exec([backendDir + "/questline-sound", event]);
    }

    property Process opening: Process {}
    property Process completion: Process {}
    property Process swarm: Process {}
    property Process hydration: Process {}
}

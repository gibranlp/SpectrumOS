import QtQuick

Loader {
    id: content
    property bool requested: false
    active: false
    asynchronous: false

    // Conserva la instancia y sus borradores después de la primera apertura.
    function ensureLoaded(): void { active = true; }
    onRequestedChanged: if (requested) ensureLoaded()
    Component.onCompleted: if (requested) ensureLoaded()
}

import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    Shell.MediaArtwork { id: artwork }
    TestCase {
        name: "MediaArtwork"
        when: windowShown
        function init() {
            artwork.artUrl = "";
        }
        function test_missingArtworkUsesFallback() {
            compare(artwork.hasArtwork, false);
            compare(artwork.imageStatus, Image.Null);
        }
        function test_loadChangeErrorAndRecovery() {
            artwork.artUrl = Qt.resolvedUrl("../../configs/spectrum-shell/igor/head-base.svg").toString();
            tryCompare(artwork, "hasArtwork", true);
            artwork.artUrl = Qt.resolvedUrl("missing-album-cover.png").toString();
            tryCompare(artwork, "imageStatus", Image.Error);
            compare(artwork.hasArtwork, false);
            artwork.artUrl = Qt.resolvedUrl("../../configs/spectrum-shell/igor/head-base.svg").toString();
            tryCompare(artwork, "hasArtwork", true);
            artwork.artUrl = "";
            compare(artwork.hasArtwork, false);
        }
    }
}

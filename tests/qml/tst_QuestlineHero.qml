import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    width: 1500
    height: 900
    QtObject {
        id: theme
        property string fontFamily: "Sans"
        property int fontSize: 14
        property QtObject colors: QtObject {
            property color background: "#101820"
            property color surface_alt: "#203040"
            property color foreground: "#eeeeee"
            property color muted: "#aaaaaa"
            property color accent: "#60bfff"
            property color error: "#ff6060"
        }
    }
    Shell.QuestlineHero { id: hero; anchors.fill: parent; theme: theme }
    TestCase {
        name: "QuestlineHero"
        when: windowShown
        function test_progressUsesCurrentLevelXP() {
            hero.hero = { username: "Hero", class: "Code Warlock", level: 10, xp: 700, xp_next_level: 1400,
                powers: [{ level: 1, name: "First", description: "First power", unlocked: true },
                         { level: 15, name: "Next", description: "Next power", unlocked: false }] };
            compare(hero.progress, 0.5);
            compare(hero.unlockedPowers.length, 1);
            compare(hero.nextPower.name, "Next");
            hero.hero = { level: 10, xp: 2000, xp_next_level: 1400 };
            compare(hero.progress, 1);
        }
        function test_maximumLevelAndMissingMetadata() {
            hero.hero = { level: 100, xp: 0, xp_next_level: 0 };
            compare(hero.maximumLevel, true);
            compare(hero.progress, 1);
            compare(hero.nextPower, null);
            hero.hero = { level: 1, xp: 10 };
            compare(hero.progress, 0);
            compare(hero.powers.length, 0);
            hero.hero = null;
            compare(hero.progress, 0);
            compare(hero.unlockedPowers.length, 0);
        }
    }
}

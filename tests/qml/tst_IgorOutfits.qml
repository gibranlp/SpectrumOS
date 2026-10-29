import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell
import "../../configs/spectrum-shell/IgorOutfits.js" as Outfits

Item {
    width: 800
    height: 400
    Rectangle { anchors.fill: parent; color: "#cbc5bb" }
    Shell.IgorIllustration { id: cat; x: 80; y: 80; width: 640; height: 262.4 }
    Shell.IgorStage { id: stage; visible: false }
    Shell.IgorSleeper { id: sleeper; x: 1000 }

    TestCase {
        name: "IgorOutfits"
        when: windowShown
        property var outfit
        property var clock

        function init() {
            outfit = findChild(cat, "igorSeasonalOutfit");
            clock = findChild(cat, "igorOutfitClock");
            clock.running = false;
            cat.outfitVisitActive = false;
            outfit.randomSource = () => 1;
            outfit.visitRoll = 1;
            cat.playing = false;
            cat.watching = false;
            cat.meeting = false;
            cat.blink = 0;
        }

        function test_exactDatesAcrossWholeYears() {
            for (const year of [2026, 2027, 2028]) {
                for (let month = 0; month < 12; month++) {
                    const days = new Date(year, month + 1, 0).getDate();
                    for (let day = 1; day <= days; day++) {
                        for (const hour of [0, 12, 23]) {
                            for (const roll of [0, 0.49, 0.5, 0.99, 1]) {
                                const expected = month === 10 && (day === 1 || day === 2)
                                    ? "day-of-the-dead" : month === 11 && day === 25 ? "christmas"
                                    : month === 11 && roll < 0.5 ? "christmas-lights" : "";
                                const selected = Outfits.forDate(new Date(year, month, day, hour, 59, 59), roll);
                                compare(selected ? selected.id : "", expected);
                            }
                        }
                    }
                }
            }
            compare(Outfits.forDate(new Date(NaN)), null);
        }

        function test_rolloverUpdatesRenderedOutfit() {
            outfit.visitRoll = 0;
            for (const date of [new Date(2026, 9, 31, 23, 59, 59), new Date(2026, 10, 1),
                                new Date(2026, 10, 2, 23, 59, 59), new Date(2026, 10, 3),
                                new Date(2026, 10, 30, 23, 59, 59), new Date(2026, 11, 1),
                                new Date(2026, 11, 24, 23, 59, 59), new Date(2026, 11, 25),
                                new Date(2026, 11, 26), new Date(2026, 11, 31, 23, 59, 59), new Date(2027, 0, 1)]) {
                outfit.currentDate = date;
                const selected = Outfits.forDate(date, outfit.visitRoll);
                compare(outfit.outfitId, selected ? selected.id : "");
                if (selected) {
                    tryCompare(outfit, "status", Image.Ready);
                    verify(outfit.source.toString().endsWith(selected.asset));
                } else {
                    compare(outfit.source.toString(), "");
                }
            }
        }

        function test_decemberChoiceStaysUntilNextVisit() {
            let rolls = 0;
            outfit.randomSource = () => { rolls++; return rolls === 1 ? 0.1 : 0.9; };
            cat.outfitVisitActive = true;
            outfit.currentDate = new Date(2026, 11, 10);
            compare(rolls, 1);
            compare(outfit.outfitId, "christmas-lights");
            cat.playing = true;
            cat.playing = false;
            cat.blink = 1;
            cat.blink = 0;
            cat.headReveal = 0;
            cat.headReveal = 1;
            outfit.currentDate = new Date(2026, 11, 10, 12);
            compare(rolls, 1);
            compare(outfit.outfitId, "christmas-lights");
            cat.outfitVisitActive = false;
            compare(rolls, 1);
            cat.outfitVisitActive = true;
            outfit.currentDate = new Date(2026, 11, 10, 14);
            compare(rolls, 2);
            compare(outfit.outfitId, "");
            outfit.currentDate = new Date(2026, 11, 25);
            compare(outfit.outfitId, "christmas");
        }

        function test_visitsAndNapsStartOutfitChoiceBeforeHeadReveal() {
            stage.pawsFirstProbability = 1;
            stage.visiting = true;
            compare(stage.headReveal, 0);
            verify(findChild(stage, "igorSeasonalOutfit").visitActive);
            stage.visiting = false;
            verify(!findChild(stage, "igorSeasonalOutfit").visitActive);
            sleeper.pawsFirstProbability = 1;
            sleeper.active = true;
            compare(sleeper.headReveal, 0);
            verify(findChild(sleeper, "igorSeasonalOutfit").visitActive);
            sleeper.active = false;
            verify(!findChild(sleeper, "igorSeasonalOutfit").visitActive);
        }

        function test_followsHeadAndCoexistsWithMedia() {
            outfit.currentDate = new Date(2026, 10, 1);
            compare(outfit.parent, findChild(cat, "igorHead"));
            cat.playing = true;
            verify(findChild(cat, "igorHeadphones").visible);
            compare(outfit.outfitId, "day-of-the-dead");
            cat.playing = false;
            cat.watching = true;
            verify(findChild(cat, "igorMovieGlasses").visible);
            compare(outfit.outfitId, "day-of-the-dead");
            cat.watching = false;
            cat.meeting = true;
            verify(findChild(cat, "igorMeetingMicrophone").visible);
        }

        function test_clockRefreshesWithoutRestart() {
            outfit.currentDate = new Date(2000, 0, 1);
            clock.interval = 10;
            clock.running = true;
            tryVerify(() => outfit.currentDate.getFullYear() === new Date().getFullYear());
            clock.running = false;
            const selected = Outfits.forDate(new Date());
            compare(outfit.outfitId, selected ? selected.id : "");
        }

        function test_visuals() {
            outfit.visitRoll = 0;
            for (const entry of [{month: 10, day: 1, name: "mask"}, {month: 11, day: 25, name: "santa"},
                                {month: 11, day: 10, name: "lights"}]) {
                outfit.currentDate = new Date(2026, entry.month, entry.day);
                tryCompare(outfit, "status", Image.Ready);
                wait(30);
                grabImage(cat).save("/tmp/igor-outfit-" + entry.name + ".png");
                cat.blink = 1;
                wait(30);
                grabImage(cat).save("/tmp/igor-outfit-" + entry.name + "-blink.png");
                cat.blink = 0;
            }
        }
    }
}

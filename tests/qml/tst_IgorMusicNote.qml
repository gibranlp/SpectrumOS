import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    width: 400
    height: 300
    Shell.IgorMusicNote {
        id: note
        x: 100
        y: 180
        width: 180
        minimumInterval: 200
        maximumInterval: 250
        flightDuration: 160
    }
    Shell.IgorStage {
        id: stage
        musicNoteColors: ["#aabbcc", "#112233"]
    }
    TestCase {
        name: "IgorMusicNote"
        when: windowShown
        function init() {
            note.active = false;
            note.paletteColors = [];
            note.random = Math.random;
        }
        function test_eachEmissionChoosesFromCurrentPalette() {
            note.paletteColors = ["#e7c100", "#8e8b8c", "#78dba9"];
            note.active = true;
            const glyph = findChild(note, "igorMusicNoteGlyph");
            for (let i = 0; i < 3; i++) {
                note.random = () => (i + 0.5) / 3;
                note.emitNote();
                compare(String(glyph.color), note.paletteColors[i]);
            }
        }
        function test_paletteChangesUpdateAnEmittedNote() {
            note.paletteColors = ["#e7c100", "#8e8b8c"];
            note.random = () => 0.75;
            note.active = true;
            note.emitNote();
            const glyph = findChild(note, "igorMusicNoteGlyph");
            compare(String(glyph.color), "#8e8b8c");
            note.paletteColors = ["#123456", "#abcdef"];
            compare(String(glyph.color), "#abcdef");
            note.paletteColors = ["#654321"];
            compare(String(glyph.color), "#654321");
        }
        function test_stagePassesThePaletteToMusicNotes() {
            const musicNote = findChild(stage, "igorMusicNote");
            verify(musicNote !== null);
            compare(musicNote.paletteColors, stage.musicNoteColors);
            stage.musicNoteColors = ["#998877"];
            compare(musicNote.paletteColors, stage.musicNoteColors);
        }
        function test_occasionalNoteFloatsAndFades() {
            note.active = true;
            tryCompare(note, "emitting", true, 500);
            const glyph = findChild(note, "igorMusicNoteGlyph");
            const startY = glyph.y;
            wait(40);
            verify(note.progress > 0);
            verify(glyph.y < startY);
            verify(glyph.opacity > 0 && glyph.opacity < 1);
            verify(note.symbol === "♪" || note.symbol === "♫");
        }
        function test_hidingOrPausingStopsNotesImmediately() {
            note.active = true;
            note.emitNote();
            verify(note.emitting);
            note.active = false;
            verify(!note.emitting);
            verify(!note.visible);
            wait(180);
            verify(!note.emitting);
        }
        function test_inactiveCannotEmit() {
            note.emitNote();
            verify(!note.emitting);
        }
    }
}

import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

Item {
    width: 600; height: 700
    Shell.ScreensaverState { id: saverState }
    QtObject { id: selectedPlayer; property bool isPlaying: false }
    QtObject { id: videoPlayer; property bool isPlaying: false; property bool canControl: false }
    QtObject { id: videoWindow; property bool fullscreen: false }
    Shell.ScreensaverActivity { id: activity; players: [selectedPlayer, videoPlayer]; windows: [videoWindow] }
    QtObject {
        id: theme
        property var colors: ({foreground: "#eeeeee", background: "#111111", surface_alt: "#333333", accent: "#66ccee", muted: "#aaaaaa"})
        property string fontFamily: "sans-serif"
        property int fontSize: 14
        property bool actionBusy: false
        property bool screensaverBusy: false
        property string screensaverError: ""
        property var screensaverSettings: ({enabled: true, timeout: 180})
        property var commands: []
        function configureScreensaver(key, value) { commands = commands.concat([[key, value]]); }
        function previewScreensaver() { commands = commands.concat([["preview"]]); }
    }
    Shell.ScreensaverControls { id: controls; width: 400; theme: theme }
    Shell.ScreensaverScene {
        id: scene
        y: 490; width: 600; height: 210
        colors: theme.colors
    }
    TestCase {
        name: "Screensaver"
        when: windowShown
        function init() {
            saverState.dismiss(); saverState.enabled = true; saverState.blocked = false;
            saverState.idle = false; saverState.armed = true; saverState.sessionAllowed = true;
            theme.commands = []; theme.screensaverBusy = false;
            theme.screensaverSettings = {enabled: true, timeout: 180};
            scene.running = false; scene.visible = true;
            selectedPlayer.isPlaying = false; videoPlayer.isPlaying = false; videoWindow.fullscreen = false;
            activity.players = [selectedPlayer, videoPlayer]; activity.windows = [videoWindow];
        }
        function test_requires_real_idle_for_automatic_start() {
            verify(!saverState.start(false)); saverState.idle = true;
            verify(saverState.start(false)); verify(saverState.active);
            saverState.idle = false; verify(!saverState.active);
        }
        function test_any_playing_player_blocks_even_with_paused_selected_player() {
            verify(!activity.blocked);
            videoPlayer.isPlaying = true;
            verify(activity.mediaPlaying); verify(activity.blocked);
            verify(!selectedPlayer.isPlaying); verify(!videoPlayer.canControl);
            videoPlayer.isPlaying = false;
            verify(!activity.blocked);
        }
        function test_fullscreen_blocks_even_without_media_metadata() {
            activity.players = []; videoWindow.fullscreen = true;
            verify(activity.fullscreenActive); verify(activity.blocked);
            videoWindow.fullscreen = false; verify(!activity.blocked);
        }
        function test_combined_guards_stay_blocked_until_both_clear() {
            videoWindow.fullscreen = true; videoPlayer.isPlaying = true;
            videoPlayer.isPlaying = false; verify(activity.blocked);
            videoWindow.fullscreen = false; verify(!activity.blocked);
            videoPlayer.isPlaying = true; activity.players = []; verify(!activity.blocked);
        }
        function test_playback_start_dismisses_an_existing_saver() {
            saverState.blocked = Qt.binding(() => activity.blocked);
            saverState.idle = true; verify(saverState.start(false));
            videoPlayer.isPlaying = true; verify(!saverState.active);
            verify(!saverState.start(false));
            videoPlayer.isPlaying = false; saverState.idle = false; saverState.idle = true;
            verify(saverState.start(false));
            saverState.blocked = false;
        }
        function test_manual_dismiss_waits_for_new_idle_cycle() {
            saverState.idle = true; verify(saverState.start(false)); saverState.dismiss();
            verify(!saverState.start(false)); saverState.idle = false; saverState.idle = true;
            verify(saverState.start(false));
        }
        function test_recording_or_gaming_block_idle_start_and_dismiss_active_saver() {
            saverState.idle = true;
            verify(saverState.start(false));
            saverState.blocked = true;
            verify(!saverState.active);
            verify(!saverState.start(false));
            verify(!saverState.start(true));
            saverState.blocked = false;
            saverState.idle = false;
            saverState.idle = true;
            verify(saverState.start(false));
        }
        function test_lock_and_inhibition_hide_active_saver() {
            verify(saverState.start(true)); saverState.sessionAllowed = false; verify(!saverState.active);
            verify(!saverState.start(true)); saverState.sessionAllowed = true; verify(saverState.start(true));
            saverState.blocked = true; verify(!saverState.active); verify(!saverState.start(true));
        }
        function test_disabled_allows_preview_but_not_automatic_start() {
            saverState.enabled = false; saverState.idle = true;
            verify(!saverState.start(false)); verify(saverState.start(true));
        }
        function test_settings_controls_send_actions_and_wait_for_saved_state() {
            mouseClick(findChild(controls, "screensaver-enabled"));
            compare(theme.commands[0], ["enabled", "off"]);
            verify(findChild(controls, "screensaver-enabled").checked);
            mouseClick(findChild(controls, "screensaver-timeout-300"));
            compare(theme.commands[1], ["timeout", 300]);
            mouseClick(findChild(controls, "screensaver-timeout-600"));
            compare(theme.commands[2], ["timeout", 600]);
            mouseClick(findChild(controls, "screensaver-timeout-900"));
            compare(theme.commands[3], ["timeout", 900]);
            compare(findChild(controls, "screensaver-branding-logo"), null);
            compare(findChild(controls, "screensaver-effect-rain"), null);
        }
        function test_busy_disables_actions() {
            theme.screensaverBusy = true;
            verify(!findChild(controls, "screensaver-enabled").enabled);
            verify(!findChild(controls, "screensaver-timeout-900").enabled);
        }
        function test_animation_stops_when_inactive() {
            scene.running = true; tryVerify(() => scene.frameCount > 0, 2000);
            scene.running = false; const frames = scene.frameCount; wait(90); compare(scene.frameCount, frames);
        }
        function test_matrix_distance_field_atlas_is_available() {
            const atlas = findChild(scene, "screensaver-matrix-glyphs");
            tryCompare(atlas, "status", Image.Ready, 2000);
            compare(atlas.sourceSize.width, 512);
            compare(atlas.sourceSize.height, 512);
        }
        function test_matrix_glyphs_are_cached_for_reuse() {
            const atlas = findChild(scene, "screensaver-glyph-atlas");
            tryCompare(atlas, "ready", true, 1000);
            compare(atlas.height, scene.glyphCell * 3);
            verify(atlas.width > 500);
        }
        function test_animation_reuses_alphabet_without_rasterizing_columns() {
            const atlas = findChild(scene, "screensaver-glyph-atlas");
            tryCompare(atlas, "ready", true, 1000);
            const builds = atlas.builds;
            scene.reset();
            for (let index = 0; index < 3; index++) {
                scene.elapsed = index + 1;
                findChild(scene, "screensaver-canvas").requestPaint();
                wait(40);
            }
            compare(atlas.builds, builds);
            compare(findChild(scene, "screensaver-stream-atlas"), null);
        }
        function test_palette_changes_rebuild_matrix_glyph_colors() {
            const previous = theme.colors;
            try {
                theme.colors = {foreground: "#ff6666", background: "#110000", surface_alt: "#330000", accent: "#ff2222", accent_alt: "#ff4444", muted: "#aa5555"};
                tryCompare(findChild(scene, "screensaver-glyph-atlas"), "ready", true, 1000);
                scene.reset(); scene.elapsed = 21;
                findChild(scene, "screensaver-canvas").requestPaint(); wait(50);
                const image = grabImage(scene);
                let red = 0;
                for (let y = 0; y < image.height; y += 2)
                    for (let x = 0; x < image.width; x += 2)
                        if (image.red(x, y) > 80 && image.blue(x, y) < 70) red++;
                verify(red > 10);
            } finally { theme.colors = previous; }
        }
        function test_sixty_frame_budget_continues_through_long_sessions() {
            for (const time of [0, 21]) {
                scene.running = true; scene.reset(); scene.elapsed = time;
                for (let index = 0; index < 120; index++) scene.advance(1 / 120);
                compare(scene.frameCount, 60);
                fuzzyCompare(scene.elapsed, time + 1, 0.00001);
                scene.running = false;
            }
        }
        function test_hidden_scene_stops_clock_and_time() {
            scene.running = true; scene.visible = false;
            verify(!findChild(scene, "screensaver-clock").running);
            const elapsed = scene.elapsed;
            scene.advance(0.1); wait(50);
            compare(scene.elapsed, elapsed);
        }
        function test_long_frame_drops_backlog_and_bounds_time_step() {
            scene.running = true; scene.reset();
            scene.advance(4);
            fuzzyCompare(scene.elapsed, 0.1, 0.00001);
            compare(scene.frameCount, 1);
            verify(scene.paintBudget < 1 / scene.targetFps);
            scene.running = false;
        }
        function test_rain_remains_animated_after_old_branding_times() {
            const canvas = findChild(scene, "screensaver-canvas");
            for (const time of [2, 21, 57, 150]) {
                scene.elapsed = time;
                canvas.requestPaint(); wait(40);
                const first = grabImage(scene);
                scene.elapsed = time + 0.17;
                canvas.requestPaint(); wait(40);
                const second = grabImage(scene);
                let lit = 0;
                let changed = 0;
                for (let y = 0; y < first.height; y += 2)
                    for (let x = 0; x < first.width; x += 2) {
                        if (second.blue(x, y) > 60) lit++;
                        if (first.blue(x, y) !== second.blue(x, y)) changed++;
                    }
                verify(lit > 10, "Matrix rain must stay visible");
                verify(changed > 10, "Symbols and trails must keep changing");
            }
        }
    }
}

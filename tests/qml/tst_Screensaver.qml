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
        property var screensaverSettings: ({enabled: true, timeout: 180, effect: "matrix", branding: "alternate"})
        property var commands: []
        function configureScreensaver(key, value) { commands = commands.concat([[key, value]]); }
        function previewScreensaver() { commands = commands.concat([["preview"]]); }
    }
    Shell.ScreensaverControls { id: controls; width: 400; theme: theme }
    Shell.ScreensaverScene {
        id: scene
        y: 490; width: 600; height: 210
        colors: theme.colors
        masks: ({wordmark: {points: Array.from({length: 25}, (_, index) => [index % 5 / 4, Math.floor(index / 5) / 4]), aspect: 3}, logo: {points: [], aspect: 1}})
    }
    TestCase {
        name: "Screensaver"
        when: windowShown
        function init() {
            saverState.dismiss(); saverState.enabled = true; saverState.blocked = false;
            saverState.idle = false; saverState.armed = true; saverState.sessionAllowed = true;
            theme.commands = []; theme.screensaverBusy = false;
            theme.screensaverSettings = {enabled: true, timeout: 180, effect: "matrix", branding: "alternate"};
            scene.running = false; scene.visible = true; scene.effect = "matrix"; scene.branding = "alternate";
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
            mouseClick(findChild(controls, "screensaver-effect-rain"));
            compare(theme.commands[2], ["effect", "rain"]);
            mouseClick(findChild(controls, "screensaver-branding-logo"));
            compare(theme.commands[3], ["branding", "logo"]);
            mouseClick(findChild(controls, "screensaver-preview"));
            compare(theme.commands[4], ["preview"]);
        }
        function test_busy_disables_actions() {
            theme.screensaverBusy = true;
            verify(!findChild(controls, "screensaver-enabled").enabled);
            verify(!findChild(controls, "screensaver-preview").enabled);
        }
        function test_animation_stops_when_inactive() {
            scene.running = true; wait(90); verify(scene.frameCount > 0);
            scene.running = false; const frames = scene.frameCount; wait(90); compare(scene.frameCount, frames);
        }
        function test_matrix_glyphs_are_cached_for_reuse() {
            const atlas = findChild(scene, "screensaver-glyph-atlas");
            tryCompare(atlas, "ready", true, 1000);
            compare(atlas.height, 48);
            verify(atlas.width > 500);
        }
        function test_palette_changes_rebuild_matrix_glyph_colors() {
            const previous = theme.colors;
            try {
                theme.colors = {foreground: "#ff6666", background: "#110000", surface_alt: "#330000", accent: "#ff2222", accent_alt: "#ff4444", muted: "#aa5555"};
                tryCompare(findChild(scene, "screensaver-glyph-atlas"), "ready", true, 1000);
                scene.reset(); scene.elapsed = 7;
                findChild(scene, "screensaver-canvas").requestPaint(); wait(50);
                const image = grabImage(scene);
                let red = 0;
                for (let y = 0; y < image.height; y += 2)
                    for (let x = 0; x < image.width; x += 2)
                        if (image.red(x, y) > 80 && image.blue(x, y) < 70) red++;
                verify(red > 10);
            } finally { theme.colors = previous; }
        }
        function test_sixty_frame_budget_is_unchanged_during_formation_hold() {
            for (const time of [0, 7]) {
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
        function test_branding_forms_and_disperses_and_cycles() {
            scene.elapsed = 7; compare(scene.formation, 1); compare(scene.currentBranding, "wordmark");
            scene.elapsed = 13; compare(scene.formation, 0);
            scene.elapsed = 21; compare(scene.currentBranding, "logo"); compare(scene.targetMask, scene.masks.wordmark);
            scene.effect = "cycle"; scene.elapsed = 0; compare(scene.currentEffect, "matrix");
            scene.elapsed = 28; compare(scene.currentEffect, "rain");
            scene.elapsed = 56; compare(scene.currentEffect, "constellation");
        }
        function test_assembled_brand_keeps_moving_in_all_effects() {
            for (const effect of ["matrix", "rain", "constellation"]) {
                scene.effect = effect; scene.reset(); scene.elapsed = 7;
                const canvas = findChild(scene, "screensaver-canvas");
                canvas.requestPaint(); wait(40);
                const first = grabImage(scene);
                scene.elapsed = 7.7;
                compare(scene.formation, 1);
                canvas.requestPaint(); wait(40);
                const second = grabImage(scene);
                let changed = 0;
                for (let y = 0; y < first.height; y += 2)
                    for (let x = 0; x < first.width; x += 2)
                        if (first.red(x, y) !== second.red(x, y) || first.blue(x, y) !== second.blue(x, y)) changed++;
                verify(changed > 5, effect + " must keep moving while the brand holds");
            }
        }
        function test_all_effects_render_and_track_palette() {
            for (const effect of ["matrix", "rain", "constellation"]) {
                scene.effect = effect; scene.reset(); scene.elapsed = 9;
                findChild(scene, "screensaver-canvas").requestPaint(); wait(60);
                const image = grabImage(scene);
                verify(image.width > 0);
                verify(image.red(0, 0) < 40);
                let illuminated = 0;
                for (let y = 0; y < image.height; y += 2)
                    for (let x = 0; x < image.width; x += 2)
                        if (image.blue(x, y) > 60) illuminated++;
                verify(illuminated > 10, effect + " must actually render the assembled particles");
            }
        }
    }
}

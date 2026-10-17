import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell
import "../../configs/spectrum-shell/MediaKind.js" as MediaKind

Item {
    id: scene
    width: 640
    height: 420
    Rectangle { anchors.fill: parent; color: "#48434b" }
    Shell.IgorStage {
        id: stage
        anchors.fill: parent
        catSize: 260
        animationDuration: 0
        pawsFirstProbability: 0
    }
    TestCase {
        name: "IgorMovie"
        when: windowShown
        function init() {
            stage.visiting = false;
            stage.watching = false;
            stage.playing = false;
            stage.animationsEnabled = true;
            stage.edge = "bottom";
            stage.celebrationMessage = "";
            wait(30);
        }
        function test_classification_data() {
            return [
                {tag:"stash", identity:"STASH Music Player", url:"", kind:"music"},
                {tag:"spotify", identity:"Spotify", url:"", kind:"music"},
                {tag:"youtube-music", identity:"Brave", url:"https://music.youtube.com/watch?v=abc", kind:"music"},
                {tag:"youtube-video", identity:"Brave", url:"https://www.youtube.com/watch?v=abc", kind:"video"},
                {tag:"spotify-web", identity:"Brave", url:"https://open.spotify.com/track/123", kind:"music"},
                {tag:"disneyplus", identity:"Brave", url:"https://www.disneyplus.com/play/123", kind:"video"},
                {tag:"primevideo", identity:"Brave", url:"https://www.primevideo.com/detail/123", kind:"video"},
                {tag:"vlc-no-url", identity:"VLC media player", url:"", kind:"video"},
                {tag:"youtube-app", identity:"YouTube", url:"", kind:"video"},
                {tag:"netflix-app", identity:"Netflix", url:"", kind:"video"},
                {tag:"disney-app", identity:"Disney+", url:"", kind:"video"},
                {tag:"prime-app", identity:"Prime Video", url:"", kind:"video"},
                {tag:"youtube-short-url", identity:"Brave", url:"https://youtu.be/abc", kind:"video"},
                {tag:"netflix", identity:"Chrome", url:"https://www.netflix.com/watch/123", kind:"video"},
                {tag:"vlc-film", identity:"VLC media player", url:"file:///tmp/movie.mkv", kind:"video"},
                {tag:"vlc-song", identity:"VLC media player", url:"file:///tmp/song.FLAC?x=1", kind:"video"},
                {tag:"audio-mime", identity:"Unknown", url:"", mime:"audio/ogg", kind:"music"},
                {tag:"video-mime", identity:"Unknown", url:"", mime:"video/mp4", kind:"video"},
                {tag:"browser-unknown", identity:"Brave", url:"", kind:"video"},
                {tag:"firefox-unknown", identity:"Firefox", url:"", kind:"video"},
                {tag:"browser-audio", identity:"Brave", url:"", mime:"audio/ogg", kind:"music"},
                {tag:"google-chrome", identity:"Google Chrome", url:"", kind:"video"},
                {tag:"zen-browser", identity:"Zen Browser", url:"", kind:"video"},
                {tag:"zen-id", identity:"org.mpris.MediaPlayer2.zen.instance1", url:"", kind:"video"},
                {tag:"apple-music", identity:"Google Chrome", url:"https://music.apple.com/us/album/123", kind:"music"},
                {tag:"deezer", identity:"Zen Browser", url:"https://www.deezer.com/track/123", kind:"music"},
                {tag:"soundcloud", identity:"Zen Browser", url:"https://soundcloud.com/artist/song", kind:"music"},
                {tag:"tidal", identity:"Google Chrome", url:"https://listen.tidal.com/track/123", kind:"music"},
                {tag:"amazon-music", identity:"Zen Browser", url:"https://music.amazon.com/albums/123", kind:"music"},
                {tag:"hulu", identity:"Zen Browser", url:"https://www.hulu.com/watch/123", kind:"video"},
                {tag:"crunchyroll", identity:"Zen Browser", url:"https://www.crunchyroll.com/watch/123", kind:"video"},
                {tag:"unknown-player", identity:"Unknown player", url:"", kind:"unknown"},
                {tag:"host-boundary", identity:"Browser", url:"https://music.youtube.com.example.test/watch", kind:"unknown"}
            ];
        }
        function test_classification(data) {
            compare(MediaKind.classify({identity:data.identity, metadata:{"xesam:url":data.url,"xesam:contentType":data.mime || ""}}),data.kind);
            compare(MediaKind.classify(null), "unknown");
        }
        function test_stash_dbus_identity_without_track_url() {
            compare(MediaKind.classify({dbusName:"org.mpris.MediaPlayer2.stash", metadata:{}}), "music");
        }
        function beginMovie() {
            stage.watching = true;
            stage.visiting = true;
            tryCompare(findChild(stage, "igorRevealMotion"), "progress", 1);
        }
        function test_glasses_replace_headphones_and_notes() {
            beginMovie();
            verify(findChild(stage, "igorMovieGlasses").visible);
            verify(!findChild(stage, "igorHeadphones").visible);
            verify(!findChild(stage, "igorMusicNote").active);
            stage.watching = false;
            stage.playing = true;
            verify(!findChild(stage, "igorMovieGlasses").visible);
            verify(findChild(stage, "igorHeadphones").visible);
            verify(!stage.startle());
        }
        function test_reaction_hides_behind_each_frame_data() {
            return ["top","bottom","left","right"].map(edge => ({tag:edge,edge:edge}));
        }
        function test_reaction_hides_behind_each_frame(data) {
            stage.edge = data.edge;
            beginMovie();
            verify(stage.startle());
            compare(stage.movieMood,"startled");
            tryCompare(stage,"movieReveal",0,800);
            const image = grabImage(scene);
            let catPixels = 0;
            for (let x = 0; x < scene.width; x += 4)
                for (let y = 0; y < scene.height; y += 4)
                    if (image.red(x,y) !== 72 || image.green(x,y) !== 67 || image.blue(x,y) !== 75) catPixels++;
            compare(catPixels,0,"The frame must hide the entire cat, including paws and glasses");
        }
        function test_returns_with_glasses() {
            beginMovie();
            verify(stage.startle());
            tryCompare(stage,"movieMood","peeking",1800);
            tryCompare(stage,"movieReveal",0.8,1000);
            tryCompare(stage,"movieMood","watching",1800);
            compare(stage.movieReveal,1);
            verify(findChild(stage,"igorMovieGlasses").visible);
        }
        function test_cancel_on_pause_music_or_disabled_animations_data() {
            return ["pause","music","disabled","celebration"].map(reason => ({tag:reason,reason:reason}));
        }
        function test_cancel_on_pause_music_or_disabled_animations(data) {
            beginMovie();
            verify(stage.startle());
            tryCompare(stage,"movieReveal",0,800);
            if (data.reason === "pause") stage.watching = false;
            else if (data.reason === "music") stage.playing = true;
            else if (data.reason === "disabled") stage.animationsEnabled = false;
            else stage.celebrationMessage = "Well done";
            compare(stage.movieReveal,1);
            compare(stage.movieMood,"watching");
            verify(!stage.startle());
            wait(40);
            compare(stage.movieReveal,1);
        }
    }
}

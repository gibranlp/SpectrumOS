.pragma library

function classify(player) {
    if (!player) return "unknown";
    const metadata = player.metadata || {};
    const url = String(metadata["xesam:url"] || "").toLowerCase();
    const mime = String(metadata["xesam:contentType"] || metadata["vlc:content-type"] || "").toLowerCase();
    const identity = [player.identity, player.desktopEntry, player.dbusName].join(" ").toLowerCase();
    if (/(stash|spotify|youtube music)/.test(identity)) return "music";
    if (/(vlc|youtube|netflix|disney\+|disneyplus|disney plus|prime video|primevideo)/.test(identity)) return "video";
    if (mime.startsWith("video/")) return "video";
    if (mime.startsWith("audio/")) return "music";
    if (/\.(mp4|mkv|webm|avi|mov|m4v|mpeg|mpg|ts|ogv)(?:[?#]|$)/.test(url)) return "video";
    if (/\.(mp3|flac|wav|ogg|opus|m4a|aac|aiff|wma)(?:[?#]|$)/.test(url)) return "music";
    if (/^https?:\/\/(music\.youtube\.com|open\.spotify\.com|music\.apple\.com|music\.amazon\.com|(?:listen\.)?tidal\.com|(?:www\.)?(deezer\.com|soundcloud\.com|qobuz\.com|bandcamp\.com))\//.test(url)) return "music";
    if (/^https?:\/\/(?:www\.)?(youtube\.com|youtu\.be|netflix\.com|twitch\.tv|vimeo\.com|disneyplus\.com|primevideo\.com|hulu\.com|max\.com|crunchyroll\.com|dailymotion\.com|tv\.apple\.com)\//.test(url)) return "video";
    if (/(stash|youtube music|spotify|rhythmbox|strawberry|clementine|audacious|amberol|lollypop|quodlibet|tauon|elisa|apple music|amazon music|deezer|soundcloud|tidal|qobuz|bandcamp)/.test(identity)) return "music";
    if (/(vlc|mpv|celluloid|parole|totem|showtime|haruna|smplayer)/.test(identity)) return "video";
    if (/(brave|chromium|chrome|firefox|zen[ ._-]?browser|\bzen\b|vivaldi|microsoft-edge|microsoft edge|opera)/.test(identity)) return "video";
    return "unknown";
}

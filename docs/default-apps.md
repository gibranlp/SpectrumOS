# Default Applications

Open **Default Applications** with **Super + Shift + G**, from the bar’s More menu, the Detailed profile’s widget icons, or the application launcher.

Common defaults cover web browser, email, file manager, videos, music, images, text, PDF, documents, spreadsheets, presentations and archives. The widget shows the effective current application for each format, including mixed defaults. Select a compatible installed application and press **Apply** to change the listed formats. Opening the widget, choosing a category or changing the application selection does not save anything.

To use VLC for common videos, choose **Videos → VLC media player → Apply to 7 file types**. This includes MP4, MKV (`video/x-matroska`), WebM, QuickTime, AVI, MPEG and Ogg video. An old `video/matroska` entry does not replace the actual MKV association; unrelated old entries are preserved.

For a single format, switch to **File types**, search an extension or MIME type, select the format, choose an application and apply. Searching `.mkv` selects the canonical Matroska video type. An application must support all types in a common category; use individual file types if it supports only some of them. Native applications and registered Flatpak/AppImage desktop entries are discovered through the session’s application registry. Refresh reloads the catalogue.

These are your Linux user defaults. Applications that use system associations, including Stash’s external video opening through `xdg-open`, follow them. Stash’s internal audio playback is separate; this feature does not add a one-time Open With menu inside Stash.

The helper runs as the desktop user, preserves unrelated associations/comments, updates relevant existing user desktop-specific overrides, and verifies every result using `xdg-mime query default`. It backs up affected files under `$XDG_STATE_HOME/spectrumos/default-apps/backups` (normally `~/.local/state/spectrumos/default-apps/backups`) and restores the previous values when verification fails, unless another process has changed the same file in the meantime. System-wide configuration is not edited.

The widget loads on first use, remains cached for reopening, and performs no background polling. It uses the existing monitor routing, themed controls, shared panel animation, and Top layer beneath the Overlay bar/frame.

Implementation references: [XDG MIME applications lookup order](https://specifications.freedesktop.org/mime-apps/latest/file.html), [xdg-mime](https://portland.freedesktop.org/doc/xdg-mime.html), and [GIO application information](https://docs.gtk.org/gio/iface.AppInfo.html).

Developer checks: `python3 -m unittest tests.test_default_apps` uses temporary homes and real XDG resolution, while `scripts/check-default-apps-ui` stages the actual component with a fake backend in an offscreen Quickshell process. Neither modifies live defaults nor launches a selected application.

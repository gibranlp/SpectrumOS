# AppImage Manager

Open **AppImages** from the bar's **More** menu, or search for **AppImage Manager**
in the application launcher.

Choose **Add AppImage…** and select a downloaded AppImage. SpectrumOS copies it
into `~/Applications/SpectrumOS`, makes the managed copy executable, reads its
embedded name and icon, and adds an application launcher entry. The original
download stays in place. Open the launcher again to see the new application.

Each application has **Launch**, **Replace…**, and **Remove** actions.
Replace accepts a newer downloaded AppImage and keeps the existing application
name and launcher entry. A rejected replacement leaves the previous version
available. Remove deletes the managed copy and its launcher entry; it preserves
the original download and the application's settings. **Open folder** opens the
managed storage directory.

This version supports x86-64 Type 2 AppImages with a SquashFS filesystem. Metadata
is read with `unsquashfs` without executing the AppImage. If an embedded name or
icon is unavailable, the manager uses the download's filename or a generic icon.
FUSE 2, SquashFS tools and the file chooser are included in desktop dependencies.
Updates are manual through Replace; the manager does not download applications
or promise update support for every AppImage.

The widget stores each application's metadata alongside its managed copy.
Launcher entries live under `$XDG_DATA_HOME/applications` (normally
`~/.local/share/applications`) and use stable identifiers. Applications run with
the user's normal permissions through UWSM.

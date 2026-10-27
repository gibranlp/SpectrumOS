# Thunar integration

Spectrum extends Thunar through native file associations, the standard terminal launcher and managed custom actions. Personal custom actions remain available. No additional graphical editor is installed.

## Text and code

The desktop depends on `xdg-terminal-exec`, which GLib/GIO uses for desktop launchers marked `Terminal=true`. Neovim's upstream `nvim.desktop` therefore opens in a terminal instead of reporting “Unable to find terminal required for application”. The system preference in `/etc/xdg/xdg-terminals.list` selects Kitty, then Alacritty. User `[desktop-]xdg-terminals.list` preferences retain their normal higher precedence. The [terminal launcher specification](https://github.com/Vladimir-csp/xdg-terminal-exec) documents these settings.

The system MIME map selects Neovim for 201 text/code types, including plain text, Markdown, HTML/CSS/JavaScript, Python, C/C++, shell scripts, configuration files, JSON, YAML, TOML, XML and notebook JSON. The map covers registered `text/*` types plus common application-MIME code/data formats. Calendar/contact data, image formats, media and browser URL handlers keep their separate application roles. Defaults can be overridden per type through the Default Apps widget or Thunar's Open With menu.

The October 26 local deployment also updated the owner's text/code associations explicitly, with a backup under `~/.local/state/spectrumos/thunar-usability/`. Browser URL, audio, video and other unrelated defaults were preserved. New installations receive the system policy automatically; a different existing user's explicit MIME choices retain normal precedence over the system defaults.

## Audio conversion

Select one or more audio files, right-click and choose **Convert audio**, then a format:

| Output | Settings |
| --- | --- |
| MP3 | LAME VBR quality 2, stereo |
| FLAC | Lossless encoding, compression level 5 |
| WAV | 24-bit PCM |
| OGG | Vorbis quality 6 |
| Opus | 160 kbit/s, 48 kHz |
| M4A | AAC, 192 kbit/s |

FFmpeg converts the first audio stream, requests supported text metadata, and omits video, subtitle/data streams and embedded artwork. Lossless output cannot recover detail lost in a lossy source. A new file is created beside each source; originals and existing destination files are preserved. Conflicting names receive a numbered suffix. Private temporary outputs are published only after FFmpeg succeeds, and failures or timeouts remove the partial file while allowing the rest of the batch to continue. Each file has a one-hour conversion timeout and two encoder threads. Start/completion notifications report the batch result.

The menu recognizes common MP3, FLAC, WAV/WAVE, OGG/OGA, Opus, M4A/AAC, AIFF/AIF, WMA, APE, WavPack and Matroska-audio extensions. Source files must also be classified as audio by Thunar. Unsupported or damaged inputs produce an error notification rather than replacing anything.

## Existing actions and customization

Image conversion remains under **Convert image** with PDF, PNG, JPEG, WebP, TIFF and BMP outputs. **Merge PDFs**, **Open Kitty here** and **Set as Spectrum wallpaper** remain available. Source adoption and shell startup synchronize the managed actions into `~/.config/Thunar/uca.xml`, replacing only exact managed action identifiers and retaining personal entries.

Thunar's **Edit → Configure custom actions** supports additional commands, submenus, file patterns, file-type filters and multi-file selections. Spectrum's managed entries should be changed in `scripts/thunar-actions` so future synchronization retains those changes. Personal actions should use their own identifiers. If a running Thunar process retains its previous menu after an external update, close its windows and reopen Thunar to reload the custom actions.

## Productivity menus

The managed context menu now includes:

- **Copy path**: absolute paths, paths relative to the current folder, shell-quoted paths, and `file:` URLs. Multiple paths are supported.
- **Open folder in Neovim**: opens the selected folder, or a selected file's parent, with that folder as the terminal/editor working directory.
- **Git**: status, selected-path history, selected-path changes, stage selections, and create/switch to a branch. Views open in the configured terminal and remain visible until Enter is pressed. Staging changes the index; branch creation asks for a name. No commit or push is automatic. These actions require a Git working tree.
- **Image preparation**: fit images within a chosen width/height without upscaling; create WebP copies at quality 85; remove EXIF, IPTC, XMP and comments while retaining ICC color profiles; export up to eight dominant colors to JSON and an SVG swatch strip. Animated images are rejected by these preparation actions rather than flattened silently.
- **PDF tools**: merge, extract page ranges, split into individual pages, rotate all pages by 90/180/270 degrees, and optimize PDF structure/streams with qpdf. Optimization keeps existing image quality; size reductions depend on the input. All outputs are new files or a new pages folder.
- **Audio tools**: normalize loudness, trim by seconds or timestamps, edit title/artist/album, and view readable codec/rate/channel/duration/tag information. Normalizing and trimming create FLAC copies; normalization preserves the original sample rate and targets −16 LUFS with a −1.5 dB true-peak limit. Tag edits copy the original supported container/streams, including artwork; blank fields keep existing values and `-` clears a field.
- **Organize files**: choose a destination and organize regular files by extension, modification year/month, or a project folder name. A checkbox preview shows the exact moves before anything is changed. Conflicts get numbered destinations in the plan; a conflict appearing afterward is refused. Completed moves are journaled under `~/.local/state/spectrumos/thunar/organization/` for **Undo last organization**, which also presents a preview and refuses to replace existing/changed files. Copies between filesystems are checksum-verified before removing their sources. Undo restores files, leaving any newly created empty folders available for reuse.
- **Share with SpectrumDrop**: attaches selected regular files to the existing widget. Choose Spectrum PC or Apple AirDrop, choose a recipient, and press Send. PC transfers still require the receiver code and consent. The selected-file card can be cleared. Selections are private to the user, expire after 15 minutes, and support up to 128 files. Selecting files alone does not start discovery, receiving, or a transfer. Files are revalidated before a transfer starts, and the worker skips the file chooser when the selection is supplied.

Conversion/preparation outputs are published with an atomic no-replace rename rather than relying on hard links. Inputs and existing files are preserved. File organization moves only the selections explicitly approved in its preview. Symbolic links and directories are not processed by the media/organization/sharing actions; copy-path and open-folder actions do accept folders.

The dialogs use Zenity and receive a narrow floating/centered window rule so opening a tool does not retile the project windows. `qpdf` and Git are explicit runtime dependencies. The helper runs only when invoked; it adds no background polling service.

Implementation: `scripts/thunar-productivity` and `scripts/thunar-actions`. SpectrumDrop selection handoff uses the existing adapter and `openSpectrumDropFiles` IPC method, preserving the originating focused-monitor routing and Top-layer widget geometry.

# SpectrumOS Default Wallpapers

The default collection contains the 30 supplied images `S1.png` through `S30.png`. These replace the previous SpectrumOS wallpaper sets; retain the original PNGs losslessly.

`S30.png` is the default for the ISO live desktop, installer appearance and theme colors, Limine boot-menu background, and a newly installed user's first desktop. Plymouth displays the separate 240-frame intro at approximately 50 fps.

The Base package installs all 30 images under `/usr/share/backgrounds/spectrumos/`. User adoption copies them with the same filenames into `~/Pictures/Wallpapers/`, preserving existing files. The installer activates `S30.png` and stages it for SDDM and Limine. The session wallpaper restorer uses `S30.png` when no valid saved selection exists.

The new files were supplied by the user. The previous generated-asset provenance does not describe this collection.

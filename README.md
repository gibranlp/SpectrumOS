<p align="center"><img src="assets/branding/spectrum-logo.svg" alt="SpectrumOS" width="180"></p>

# SpectrumOS

**Work. Play. Defeat the Great Backlog.**

SpectrumOS is an **Arch Linux distribution** with a keyboard-driven **Hyprland** desktop, a **Quickshell** interface, wallpaper-driven colors, and widgets for practically everything. One system for your code, your campaigns, and the suspicious number of browser tabs you call research.

**Version 1.0.0 is here.** Your distro-hopping side quest may finally take a nap.

[Explore the desktop and screenshots](https://gibranlp.dev/en/spectrum/) · [Español](https://gibranlp.dev/spectrum/) · [Download and package repository](https://spectrum.gibranlp.dev/) · [Report a bug](https://github.com/gibranlp/SpectrumOS/issues)

![SpectrumOS desktop](https://gibranlp.dev/images/spectrumos/screenshots/spectrum.png)

## Meet your new command post

Inspired by [Caelestia Shell](https://github.com/caelestia-dots/shell), SpectrumShell is built with [Quickshell](https://quickshell.org/) on [Hyprland](https://hypr.land/). The bar, widgets, launcher, notifications, and desktop interactions share one visual language. Put the bar at the top or on the left, choose a detailed or Minimal profile, and keep your tools within reach.

Window controls stay consistent across **Dwindle, Master, Scrolling, and Monocle**. Multi-monitor controls, keyboard navigation, and integrated utilities handle the practical work behind the pretty screenshots. The menu labyrinth has lost another customer.

### A widget for almost anything

| Your current encounter | Tools already in the party |
| --- | --- |
| Mission control | Control Center, Dashboard, system readings, battery and power profiles, calendar, weather, time and region |
| Connections and sound | Wi-Fi and Ethernet, Bluetooth, output/input selection, volume, microphone controls, playback and artwork |
| Screens and appearance | Monitor arrangement, resolution, refresh rate, scale, supported brightness controls, wallpapers, fonts, keyboard and mouse settings |
| Capture the evidence | Screenshots, screen recording, audio recording, and visible recording indicators |
| Small but persistent side quests | File search, calculator, passwords, emoji, color picking and saved colors |
| Stay on task | Focus timer, Questline, notification history, Do Not Disturb, keep-awake control |
| Expand the inventory | AppImage Manager, Updates, shortcuts, HotKey automation, session controls |
| Share the desk | UKVM controls and SpectrumDrop transfers on supported hardware |

Some features depend on the hardware and desktop APIs available. A widget cannot summon a missing monitor, although the Planning Council has filed a request.

## Your wallpaper, your world

Change the wallpaper and the shell, widgets, terminals, notifications, supported GTK/Qt apps, and folder colors follow. The native theme engine builds a shared semantic palette instead of asking every application to improvise.

Wallpaper filters use [Gowall by Achno](https://github.com/Achno/gowall). Recolor a scene with palettes such as Catppuccin, Nord, Gruvbox, or Dracula, then let SpectrumOS derive its desktop colors from the filtered image. Combine filters, **four palette backends**, and light/dark variants for **literally hundreds of combinations per wallpaper**. Choose `None` to return to the original colors.

The Great Backlog remains undefeated. Its wardrobe, however, is exceptional.

## Three homegrown apps. One adventuring party.

**Stash, Questline, and UKVM are included in both Full and Lean installations.** Their desktop integration is part of SpectrumOS, not a post-install scavenger hunt.

### Stash — the soundtrack to the side quest

[Source: gibranlp/stash](https://github.com/gibranlp/stash)

A keyboard-driven Rust terminal app combining a **music player, searchable library, and dual-pane file browser**.

- Queue tracks, seek, shuffle, repeat, create playlists, and edit tags.
- Follow embedded or online lyrics, with cached results and synchronized highlighting when available.
- Preview files, select batches, and copy or move them with background progress.
- Ask the **Library Healer** to suggest fixes for missing metadata, then review what to apply.
- Share playback metadata and artwork with the desktop through MPRIS, using SpectrumOS colors.

Open Stash from the launcher or run `stash`. Even `track_07_FINAL.mp3` deserves a redemption arc.

### Questline — the Great Backlog has acquired a health bar

[Source: gibranlp/Questline-cli](https://github.com/gibranlp/Questline-cli) · [Questline website](https://questlinecli.com)

Projects become **Campaigns**, tasks become **Quests**, and notes become **Scrolls**. Finish real work, earn XP, grow your Zen Tree, and give your hero a story worth telling. Behind the RPG are priorities, deadlines, steps, Markdown notes, focus sessions, ambient soundscapes, and a Treasury for project money. Work offline by default, with optional device and Fellowship sync.

Run `questline` for the terminal adventure, or press **Super + Shift + Q** for its native shell widget:

- Overview, Tasks, Scrolls, Treasury, Tree, Focus, Hero, and Sidequests views.
- Horizontal campaign buttons share the same selection across Tasks, Scrolls and Treasury.
- Create and edit work from the desktop, with **autosave and restored navigation** when you close and reopen the widget.
- Press **Super + Shift + N** for a quick Scroll in your selected project. No project selected? Choose one and start writing.

Questline 2.0.2 adds desktop alerts for actual XP gains, level-ups and unlocked achievements. A background service keeps Swarm and water reminders alive when the terminal is closed, following your existing Questline preferences. See [Questline notifications](docs/questline-notifications.md).

Capture the idea before it escapes into the Forest of Forgotten Thoughts. The Save Button has retired from active duty.

### UKVM — one keyboard, one mouse, a bigger party

[Source: gibranlp/UKVM](https://github.com/gibranlp/UKVM)

Share keyboard and mouse control between trusted Linux computers, each using its own display. Cross a configured screen edge to take control of another machine.

Open the widget with **Super + Shift + K** to discover and pair peers, arrange computers, inspect service status, and manage permissions. Text clipboard sharing and file/folder reception are **separate opt-in features**. Pairing requires verification, and desktop portal permissions remain yours to approve.

Current SpectrumOS integration focuses on **Linux Wayland with compatible desktop portals**. Keyboard and mouse control for **Windows and macOS is in development**. See the UKVM project for its current platform and remote-session work; upstream development can move ahead of the packaged release.

Your other computer is allowed to join the party. Random machines on the network are not automatically invited.

## Igor — moral support, on his terms

Igor drops by when he feels like it, waves, stretches, and occasionally decides your desktop is a first-class napping facility. **Visits are optional**; toggle them with his button on the bar.

His wardrobe follows the occasion: headphones for music, glasses for videos and movies, and a headset when a supported browser or meeting app uses the microphone. Accessory detection uses available media metadata and capture activity; voice recording can also summon the headset.

Complete tasks in the Questline widget and he may appear with commentary on your heroic productivity:

> You earned XP. I earned a nap.

Fair compensation, according to Igor.

## An equipped desktop, with room for more loot

Both Full and Lean include **Thunar, File Roller, VLC, Swayimg, Evolution, KDE Connect, Kitty, Alacritty, Blueman, GNOME Disks, Pavucontrol**, system utilities, and the three homegrown apps. Thunar handles archives, removable drives, Android MTP, image conversions, and merging multiple PDFs into a new file.

**Full** adds printing and network-sharing tools, Transmission CLI, Vesktop, and Gowall. **Lean** keeps the core desktop and skips those extras. **Google Chrome, Brave, and Zen Browser are optional installer selections**. The developer profile adds tools such as Git, Neovim, Rust tooling, CMake, Python, and ripgrep; choose profiles to suit your workflow.

### Flatpak and AppImages belong here too

- **Flatpak and Flathub:** included configuration, launcher integration for system and user applications, and Flatpak updates through the Updates widget's all-apps workflow.
- **AppImage Manager:** open AppImages from the bar's More menu or find the manager in the launcher. Add a downloaded AppImage to create a managed copy and launcher entry. Launch, replace with a newer download, remove, or open its folder from the widget. Updates are manual; original downloads and application settings are preserved when removing a managed app.
- **Pacman and Paru:** signed Arch/SpectrumOS packages use Pacman; the reviewed AUR catalog uses Paru. Several routes to a well-stocked inventory.

See [AppImage details](docs/appimages.md), [application colors](docs/application-color-integration.md), and [printing and sharing](docs/printing-and-sharing.md).

## Yes, the side quest can be a game

The optional Gaming profile brings **Steam, Lutris, Wine Staging, Winetricks, Proton GE, GameMode, Gamescope, MangoHud, GOverlay, and vkBasalt**, with matching Vulkan and 32-bit components for the selected hardware profile. Tune performance, watch frame times, and return to the boss fight.

**Automatic Gaming bar:** when a game or launcher requests GameMode, SpectrumOS temporarily switches every monitor to the Gaming bar profile. Bars and decorations step aside, animations take a break, and the available Performance power mode kicks in. After the **last GameMode client exits**, each monitor gets its previous bar profile back and the previous power mode returns—including Balanced or Power saving. Your saved profiles stay intact. Two games at once? The bar waits for the final boss to leave.

A game must actually **request GameMode**. Opening Steam, Proton, or a launcher alone does not guarantee this. Enable the launcher's GameMode option where available. For a Steam game without native integration, open **Properties → General → Launch Options** and enter:

```sh
gamemoderun %command%
```

For a standalone game or launcher, run its usual command through the wrapper:

```sh
gamemoderun /path/to/your-game
```

You can check whether GameMode is active with `gamemoded -s`. Performance power mode alone does not trigger the Gaming bar profile. You can also select Gaming manually in **Control Center (`Super + P`) → Bar Profile**; it then stays active until you leave it. Selecting another profile or **Leave Gaming** during an automatic session keeps that choice until all GameMode clients exit, then automatic activation is ready for the next session. A launcher running under GameMode counts as an active client too, so close it if you want that session to end. See [Gaming details](docs/spectrum-shell.md#gaming-profile).

Game compatibility depends on drivers, Proton, and anti-cheat support. Calling every match a benchmark remains a personal decision.

## Your spellbook, minus the memorization exam

| Shortcut | Action |
| --- | --- |
| `Super + D` | Application launcher |
| `Super + Enter` | Terminal |
| `Super + E` | Files |
| `Super + P` | Control Center |
| `Super + K` | All shortcuts, sorted by action |
| `Super + Shift + Q` | Questline widget |
| `Super + Shift + N` | Quick Scroll in the current project, or choose a project |
| `Super + Shift + K` | UKVM widget |
| `Super + Shift + U` | App Store |
| `Super + Shift + E` | AppImage Manager |
| `Super + J` | Change the current layout's arrangement |
| `Super + Tab` / `Super + Shift + Tab` | Next / previous window |
| `Super + Arrow` | Focus a window |
| `Super + Shift + Arrow` | Move a window |
| `Super + U` | Updates |

[Download the printable A3 shortcut poster](https://gibranlp.dev/downloads/spectrumos/spectrumos-shortcuts-a3-en.pdf). Even the Planning Council allows open-book quests.

## Download, install, update

Get the **x86_64 ISO and its SHA-256 checksum** from [the download page](https://spectrum.gibranlp.dev/), or explore the [visual guide](https://gibranlp.dev/en/spectrum/). Boot the live environment to inspect the installer before committing to a disk.

The installer offers Full/Lean selection, hardware profiles, **Btrfs**, and **Limine**. Installation erases the selected disk; back it up first. Manual partitioning and same-disk dual boot are not offered by this installer. A VM is useful for exploration; physical hardware acceptance is a separate test.

**Stable update notifications:** SpectrumOS checks for newer installed packages from the signed SpectrumOS Stable repository about one minute after the shell starts, then every 30 minutes. When fresh loot is ready, a notification offers **Open Updates**. Click it to open the Updates widget, review the safety checks, and choose the update action. The widget also shows the Stable package status; **Check again** refreshes it. The same set of available versions is announced once, including across shell restarts. Offline or failed checks do not invent updates, and checks use a separate package database without changing the system database or installing anything. Notifications cover SpectrumOS Stable packages; the actual update still upgrades Arch and SpectrumOS together. Your party deserves compatible equipment.

Installed systems receive Stable package updates through the widget or:

```sh
sudo pacman -Syu
```

On supported Btrfs installations, the update workflow creates system restore points with matching boot backups, applies migrations, and checks health. Recovery restores system and boot together; home data stays outside system rollback. Heroes appreciate save points. They also keep separate backups of their actual work.

## Favorites — your portals, ranked by escape frequency

Open **Favorites** with **Super + Shift + V**, from More, or from the launcher. This wider left-side panel keeps categorized web links, automatically ranks them by use, and offers a TOP view, global search, site favicons, autosaving editors, JSON import/export, and a default-browser selector. Homepage backup imports read only `personal.links`, preserving categories and counters while merging duplicate URLs. See [the Favorites guide](docs/favorites.md).

## Make the terminal yours: aliases and custom commands

A fresh SpectrumOS install has a deliberately small `~/.zshrc`. It loads the package-owned shell defaults and then your personal `.zsh` files. The short file is the entrance to the tavern, not the entire tavern.

The defaults provide Oh My Zsh, the Spectrum prompt, plugins, and shared helpers. Your aliases, functions, and environment settings belong in your home directory:

| Personal folder | Suggested contents |
| --- | --- |
| `~/.config/spectrumos-personal/aliases/` | Aliases and command shortcuts |
| `~/.config/spectrumos-personal/zsh/` | Functions, environment variables, and other shell settings |
| `~/.config/spectrumos-personal/work/` | Optional work-specific shell settings |

### Add your aliases

Create the folders, then open a personal alias file in your editor:

```sh
mkdir -p ~/.config/spectrumos-personal/{aliases,zsh,work}
nano ~/.config/spectrumos-personal/aliases/my-aliases.zsh
```

For example, put these lines in that file:

```zsh
alias update='sudo pacman -Syu'
alias projects='cd "$HOME/Projects"'
alias ll='ls -lah'
```

The `projects` shortcut expects a `~/Projects` directory; change the destination to suit your own workspace. Save the file and open a new terminal. Your new aliases are ready for duty.

### Add functions and environment settings

Open another personal file:

```sh
nano ~/.config/spectrumos-personal/zsh/custom.zsh
```

For example:

```zsh
export EDITOR=nano

mkcd() {
    mkdir -p -- "$1" && cd -- "$1"
}
```

In a new terminal, `mkcd my-next-campaign` creates a directory and enters it. Choose your preferred installed editor for `EDITOR`. Optional syntax checks, without running the files:

```sh
zsh -n ~/.config/spectrumos-personal/aliases/my-aliases.zsh
zsh -n ~/.config/spectrumos-personal/zsh/custom.zsh
```

### How loading works

The default entrypoint reads `/usr/share/spectrumos/zsh/defaults.zsh` first, then all files ending in **`.zsh`** from **aliases → zsh → work**, in filename order within each folder. Missing folders and empty folders are fine. Names such as `10-navigation.zsh` and `20-tools.zsh` can make the order explicit. A file named only `aliases` or ending in `.txt` will not load automatically.

Personal files run after the distro defaults, so your later alias and function definitions can override earlier ones. These are ordinary executable Zsh configuration files; add settings and commands you want to run whenever an interactive terminal opens. Changes apply when you open a new terminal.

**Keep personal customization out of `/usr/share/spectrumos/zsh/`.** Those files belong to packages and can be replaced by updates. Your files under `~/.config/spectrumos-personal/` are yours to maintain, back up, and carry between installations. You may edit `~/.zshrc` too, but the personal folders keep the entrypoint small and your changes easy to find.

### Already have your own `.zshrc`?

The development installer preserves an existing `~/.zshrc`. That is why a long-standing testing machine can look different from a fresh ISO installation. **An existing custom `.zshrc` does not automatically load these folders** unless it already includes the SpectrumOS loader or explicitly sources your files.

You can keep your current setup and add these lines at the end of your existing `~/.zshrc`, after creating the example files:

```zsh
source "$HOME/.config/spectrumos-personal/aliases/my-aliases.zsh"
source "$HOME/.config/spectrumos-personal/zsh/custom.zsh"
```

That loads those two files while preserving your existing setup. The fresh-install entrypoint already loads them automatically, so it needs no extra `source` lines. Keep private work settings and credentials out of public dotfile repositories. Your aliases may be legendary; your secrets should remain undiscovered.

## Repository map

This is the canonical **SpectrumOS** source repository. The former SpectrumOS2 development tree has been consolidated here, retaining the original GitHub history. The distribution version remains **1.0.0**.

| Path | Purpose |
| --- | --- |
| `configs/` | SpectrumShell, Hyprland, terminal, login and boot defaults |
| `scripts/` | Desktop adapters, validation, packaging and release tools |
| `packages/` | PKGBUILDs, package metadata, licenses and the theme engine source |
| `installer/`, `iso/` | Live installer, recovery and ArchISO profile |
| `bootstrap/` | Package and hardware profile manifests |
| `integrations/` | Maintained app integration and SpectrumDrop sources/notices |
| `assets/` | Branding, original wallpapers and boot artwork |
| `system/`, `migrations/` | Services, release policy and upgrade migrations |
| `tests/` | Backend and QML checks |
| `repo/` | Public signing keys, repository configuration and hosting templates |
| `docs/` | Architecture, integration and release documentation |

ISOs, VMs, packages, extracted sources, caches, generated state, and private keys **do not belong in Git**. `.gitignore` keeps them local. The supplied wallpaper PNGs and required boot artwork are source assets; they stay lossless. The Questline focus companion is currently a bundled runtime dependency with corresponding Rust source and a build helper. See [repository maintenance](docs/repository-layout.md) for the size budget and artifact rules. The repo is allowed to have a personality, not its own ZIP code.

### Working on the source

Read [AGENTS.md](AGENTS.md), [architecture](docs/architecture.md), [SpectrumShell](docs/spectrum-shell.md), [theme engine](docs/theme-engine.md), and [packaging](docs/packaging.md). Some older audit notes describe earlier desktop generations; current source and release documentation take precedence.

```sh
git clone https://github.com/gibranlp/SpectrumOS.git
cd SpectrumOS
./install.sh --help
./install.sh                         # Plan only; no system changes
python3 -m unittest tests.test_iso tests.test_appimage tests.test_flatpak tests.test_thunar_actions
lua tests/test_window_actions.lua configs/hyprland/window-actions.lua
```

The root installer is a development tool for an existing Arch system; the ISO installer is the fresh-install path. Applying development phases changes managed system/session files, so read its options before using `--apply`. Hardware and package profiles are explicit selections.

Package recipes pin immutable source archives and checksums. Those release archives live at [spectrum.gibranlp.dev/sources](https://spectrum.gibranlp.dev/sources/), not in Git. Follow [packaging](docs/packaging.md) to prepare sources and clean builds. **Do not build or resume an ISO unless explicitly requested**; publishing source does not require rebuilding packages or the ISO.

## Credits, licenses, and fellow adventurers

Thanks to [Arch Linux](https://archlinux.org/), [Hyprland](https://hypr.land/), [Quickshell](https://quickshell.org/), [Caelestia Shell](https://github.com/caelestia-dots/shell), [Gowall](https://github.com/Achno/gowall), and the many upstream projects behind this desktop. Stash, Questline, and UKVM have their own linked repositories and licenses; vendored components retain their notices. Consult package and component license files for the code and artwork you use.

Found a bug? Open an issue with what happened, what you expected, steps to reproduce, relevant hardware, and sanitized logs or screenshots. Feature ideas, desktop screenshots, and reproducible boss encounters are welcome.

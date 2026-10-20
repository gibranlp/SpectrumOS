# App Store

Open **App Store** with **Super+Shift+U**, from the bar's **More** menu, or from the application launcher. The shortcuts widget, **Super+K**, includes the same action.

The gadget slides out from behind the bar and frame, keeping the bar visible and its controls accessible throughout the animation.

Search applications and packages across configured Pacman repositories, the AUR, and Flatpak remotes. Discover starts with a small selection of common applications; typing searches the selected sources. System packages include command-line tools and libraries as well as graphical applications.

Each result identifies its source. Flatpak results also identify the remote and **user** or **system** installation. The same application can appear more than once when available from several sources or scopes. Choose the variant you want; the store does not replace another variant automatically. User-scope Flatpak results appear before matching system-scope results.

## Installing

1. Open a result to inspect its package details.
2. Choose **Install in terminal**. The gadget closes and a separate Kitty window opens.
3. Enter your administrator password in that terminal when requested. Review and confirm the actual package list there. Password input is hidden and is not logged.
4. For AUR packages, review the build files using Paru’s normal terminal review. Builds run as your user. Flatpak permissions and dependency questions also remain in the terminal.
5. The terminal stays open when finished so you can inspect the result and scroll back. Reopen App Store, then open **Installed** and refresh. **Open application** appears only when a launchable desktop entry is available; technical packages show **Installed**.

System-package installation includes a full system upgrade. It uses the existing SpectrumOS preflight, Pacman signature configuration and transaction hooks, ordered migrations, and a user-session health check. A failed migration or health check is distinguished from a package transaction that did not commit. The current SpectrumOS preflight requires supported restore-point capability; the store does not bypass that gate on unsupported filesystems.

Flatpak installation presents the selected scope's dependencies and permissions before confirmation. It preserves the configured remotes and their signature verification. The store does not add remotes or install Paru automatically. Paru and the normal AUR build prerequisites must already be installed to build AUR packages.

Installation runs in an independent UWSM application scope. Reopening or restarting SpectrumShell does not close the installation terminal. You do not need to reopen the gadget for passwords or questions. Activity is an optional read-only copy of recent terminal output: it follows the bottom while you are watching progress and preserves your position when you scroll back. Closing the terminal interrupts its session, so leave it open until the transaction finishes.

## Scope and behavior

- Installed lists explicitly installed system packages and installed Flatpak applications. Foreign system packages are not assumed to be AUR packages.
- Browsing does not synchronize the live Pacman databases or install anything. AUR responses are cached briefly; Flatpak maintains its own search metadata.
- Search failures are reported per source. Available sources remain usable when another source is offline.
- Package operations are serialized with the existing Updates workflow for the current user. A root-owned lock serializes store privilege requests, and Pacman's database lock remains authoritative for other package tools.
- Administrator authentication uses terminal sudo. System-scope Flatpak installation also runs through sudo; user-scope Flatpak installation stays unprivileged. The widget never handles passwords or accepts shell commands.
- Removal, automatic updates, repository management, and ratings are outside this first version. The footer links to the existing AppImage Manager and Updates gadget.
- Native package-manager questions and AUR review are handled directly by the terminal. The earlier graphical bridge remains compatible with existing jobs; new installations do not depend on its prompt parser.

The control socket lives in the private `$XDG_RUNTIME_DIR/spectrumos/app-store/` directory, so long state paths do not exceed Unix socket limits. Private job requests, status and output-only terminal transcripts are stored under `$XDG_STATE_HOME/spectrumos/app-store/`, normally `~/.local/state/spectrumos/app-store/`. Activity reads the most recent 100,000 bytes of a terminal transcript. Reopening reads actual job state. An interrupted worker is reported as interrupted and is never replayed automatically. An AUR failure after a successful system upgrade reports those separate outcomes.

## Validation

`python3 -m unittest tests.test_app_store` covers identities, privilege boundaries, source failures, review files, safe prompts, private-socket answer tokens and interrupted jobs. Socket tests require an environment that permits private Unix sockets. `python3 tests/run_app_store.py` exercises the native widget at 620 and 1040 pixels, including actual result clicks, typing, late searches, terminal handoff and automatic panel closure, Activity wheel scrolling and position preservation, panel reopening and larger fonts.

Disposable Arch-container acceptance verified a real signed-repository Pacman install, decline without installation, an AbortOnFail hook blocking a transaction, a fresh unprivileged Paru build with the graphical review bridge, and signed local Flatpak installations in user and system scope. Container-only authentication and SpectrumOS preflight/migration doubles were used; these do not establish physical desktop authentication or paired Btrfs/EFI snapshot acceptance. Flatpak refs installed successfully, but container namespace restrictions prevented sandbox/export-helper acceptance. Host verification covers the installed widget, real read-only search, registered shortcut/policy, and the running shell; no test applications were installed on the host.

Terminal follow-up verification covers the actual Kitty/UWSM handoff, held completion and transcript using a nonexistent Flatpak source, without installing host packages. Native widget checks verify automatic closure after a successful handoff, wheel scrolling, preserved reading position and following the bottom. A real pseudo-terminal regression verifies that hidden password input is absent from output-only transcripts. Root-command tests preserve the full-upgrade preflight and migration sequence; Paru uses native terminal sudo and review.

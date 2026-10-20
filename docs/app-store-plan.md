# Spectrum App Store implementation plan

Status: implementation authorized and locally deployed, October 17, 2026. The user subsequently selected terminal installation: the gadget closes and hands passwords, confirmations and AUR review to a separate terminal. That decision supersedes the original fully graphical transaction requirement below. Package publication and ISO builds remain outside this task.

Implementation decision: the feasibility work selected a bounded Python/PTY transaction worker around the installed Pacman, Paru, and Flatpak commands, preserving their real prompts and existing configuration. Paru uses its documented `PARU_CONF`, `[bin]` review hook and privilege hook; no Rust/libalpm bridge or separate dependency solver was needed. Graphical questions and read-only AUR file review stay in the native shell, while an independent transient user service owns each job. Flatpak commands provide explicit installation scopes and resolved permissions/dependencies. See [the implemented behavior and validation limits](app-store.md).

## Goal and first release

Add a native SpectrumShell gadget named **App Store** so users can search, inspect, and install applications from configured pacman repositories, the AUR through Paru, and configured Flatpak remotes. Normal installation, authentication, review, and progress must work graphically without requiring terminal commands.

The first release includes search, app details, source selection, installation, installed-app inventory, launch, and persistent operation status. Removal, automatic orphan cleanup, remote/repository management, ratings, and automatic updates are later work. The existing AppImage Manager remains available, with a link from the store. Updates links to the existing Updates gadget until a shared graphical update engine is separately validated.

## Findings from the current project

- SpectrumShell uses native Quickshell/QML surfaces and shared palette, typography, keyboard navigation, motion, and frame geometry. Use those components rather than embedding a website or installing a separate desktop store.
- Favorites provides a useful panel/controller/content separation. AppImage Manager and the application catalog provide installed-app and launch integration patterns.
- The launcher already refreshes while visible and distinguishes Flatpak and AppImage entries. Use the existing catalog and UWSM application launch path rather than generating competing launcher entries.
- `spectrum update plan`, the pre-upgrade Pacman hook, ordered migrations, and `spectrum doctor` implement existing safety behavior. `spectrum-update-run` currently opens an interactive terminal and holds a per-user `update.lock`; it is not a graphical transaction API.
- Browsing must follow the isolated-database approach used by `spectrum-update-check`. Searching must never synchronize the live system package database.
- The reference PC has pacman, Paru, Flatpak, Polkit, Quickshell, Python GI, and usable Flatpak/AppStream GI namespaces. `pyalpm` is not installed. Flathub exists in both user and system scope. Paru is currently an optional Desktop dependency.
- The working tree contains existing changes. Implementation must preserve them and limit edits to the necessary integration points.

## User experience

Use a wide, responsive panel attached to the shell, with a search field, **Discover**, **Installed**, and **Activity** views. Open from More, an App Store desktop entry, and a shortcut selected after checking both source and live bindings. Add the shortcut to the alphabetically sorted Super+K list.

Search defaults to applications and offers **All sources**, **System packages**, **AUR**, and **Flatpak** filters. A separate **Show technical packages** option exposes libraries and command-line tools. Missing application metadata must not prevent exact package-name searches.

Results show name, icon or fallback, short description, source, and installed state. Details show version, publisher or maintainer where available, actual repository/remote, installation scope, available size estimates, homepage, license, and Flatpak permissions when available. Missing metadata is shown honestly; do not invent screenshots, ratings, or download sizes.

For an app available through several sources, show a source selector. Group only reliable AppStream/desktop-ID matches; similar display names alone are insufficient. Selecting a source is explicit and never silently replaces an installed variant. Configured third-party pacman repositories retain their real names rather than receiving an Official label.

Install flow:

1. Select an app and source.
2. Prepare the operation and show apps/dependencies, conflicts or replacements, download estimate, and any required full system upgrade.
3. For AUR, explain community maintenance and show the actual build files/diffs for the selected package and AUR dependencies before approval.
4. Confirm, authenticate through the desktop agent when needed, and show preparation/download/build/install stages.
5. Refresh installed state and offer **Open** only if a valid desktop entry exists. Technical packages show **Installed**.

Default new Flatpak installations to user scope, with an explicit system option. Detect both scopes and every configured installation; never confuse two copies of the same app. An absent backend disables only its actions and explains what is missing. Installing Paru itself must be a separate, explicit setup action rather than a hidden bootstrap.

## Architecture

| Component | Responsibility |
| --- | --- |
| `AppStorePanel.qml` | Focused-monitor panel, frame, opening/closing, and navigation |
| `AppStoreContent.qml` | Search results, detail view, source selector, and activity |
| `AppStoreManager.qml` | Shared shell controller, request IDs, selection, and live job state |
| `scripts/app-store-adapter` | Unprivileged catalog/search coordinator and structured JSON interface |
| Transaction worker and Polkit policy | Bounded privileged package operations, preparation, approvals, and progress |
| User-session job service | Keeps operations alive independently of the panel and shell process |

Use Python for the catalog adapter, consistent with current shell adapters. Prefer a Rust transaction worker using libalpm for structured official-package transactions, matching the documented direction for shared transaction logic. Validate the binding and build dependencies before committing to the implementation. Do not create a new dependency solver.

Official package queries use local/cached repository data and preserve `pacman.conf` repository priority and settings. The transaction worker must honor configured signatures, hooks, ignore rules, architecture, providers, and dependency resolution. Flatpak uses libflatpak through the available GI bindings for installation, resolved operation lists, progress, questions, and cancellation. AppStream enriches available metadata; it is not required for every package to appear.

AUR search uses the versioned AUR RPC interface; Paru remains responsible for AUR dependency/build orchestration. Run Paru and builds as the logged-in user. Prototype its configurable review, Pacman, and privilege handoffs before promising a complete GUI integration. Any prompt adapter needs a supported-version contract, bounded input, explicit GUI decisions, and failure on unrecognized prompts. Never answer arbitrary prompts automatically or use blanket `--noconfirm` as the GUI integration strategy.

Keep source identities explicit: repository plus package name; AUR package/base plus reviewed revision; Flatpak installation plus remote plus full ref. Pacman foreign packages are not automatically classified as AUR packages. Installed application entries must map to their owning package or Flatpak ref before enabling actions.

Search requests carry generation IDs so late replies cannot replace newer results. Debounce typing, cap result batches, cache by source, and cancel superseded network work. Refresh on opening and after completed operations; no continuous hidden search polling. Allow independent searches concurrently, but serialize mutations.

## Transaction and recovery contract

- The GUI and catalog remain unprivileged. The package-owned privileged worker accepts validated operation types and package identities, never arbitrary shell commands, executable paths, configuration paths, or environment overrides.
- Use desktop Polkit authentication; never collect passwords in QML. Validate caller identity and bind approvals to the prepared transaction. Re-resolve and require approval again if packages, versions, replacements, or reviewed AUR inputs change.
- Before official package changes, reuse the existing preflight rules. If refreshing system databases, perform a full system upgrade with the requested installation. Never run `pacman -Sy package` or implement selective system updates after refresh.
- Treat refreshing the live database as a transaction step, not catalog maintenance. If the user cancels afterward, record that a full upgrade is still required before subsequent official installations; recheck independently of the store's own history.
- Preserve pre-upgrade snapshot hooks and AbortOnFail behavior, then run ordered migrations and health checks after successful system upgrades. Non-Btrfs installations report the existing reduced recovery capability. Snapshot support does not imply rollback of user Flatpak data or AUR build effects.
- Coordinate store operations with the existing Updates flow. A shared system-wide lock coordinates managed pacman work; Pacman's database lock remains authoritative against external tools and other users. Recheck at transaction start and never delete someone else's lock.
- Flatpak and AUR installations are separate jobs with separate outcomes. A successful official upgrade followed by an AUR build failure must remain reported as partial success, not a rollback or complete success.
- Persist private job metadata/logs and reconnect after panel closure or shell restart. Closing the panel never cancels an installation. On worker failure or reboot, reconcile against actual installed state before offering retry; never replay a privileged operation automatically.
- Cancel downloads and builds where supported. Once a package commit or hook is running, defer cancellation until a safe boundary and explain that state in the GUI. Do not terminate Pacman during a commit.
- Show actionable messages for offline sources, authentication cancellation, low space, signature failures, locks, conflicts, and build failures. Keep technical output expandable. Do not disable signature verification or automatically repair keyrings, databases, or repositories.

## Implementation sequence and completion gates

1. **Prove graphical transactions first.** In a disposable Arch environment, exercise official resolution/commit/questions, libflatpak transactions in both scopes, and Paru review/authentication/provider/conflict flows. Verify hooks, snapshot behavior, configuration compatibility, cancellation, and worker ownership. Record supported versions and resolve the AUR integration approach before building the full UI. Completion requires an actual install without an external terminal for each backend.
2. **Build the read-only catalog.** Implement source identities, search/detail/inventory responses, application metadata, scoped Flatpak discovery, caching, stale-reply rejection, and graceful per-source failures. Verify browsing changes no system package database or installed package.
3. **Build the shell gadget.** Add the shared controller and responsive views, keyboard access, source selection, details, and mock progress. Integrate More, wrapper/IPC, launcher entry, focused-monitor behavior, close-all-panel handling, and mascot suppression. Verify palette/font changes and Full/Islands in both orientations.
4. **Connect installation jobs.** Deliver official packages and Flatpak first, then AUR with the proven review bridge. Add graphical approval/authentication, shared locking, job persistence, progress, installed-state reconciliation, and launch. AUR graphical installation remains required for the requested first release.
5. **Package and deploy locally.** Add mappings to `install.sh` and `packages/spectrum-desktop/PKGBUILD`, update `.SRCINFO`, declare runtime/build dependencies and policy/service files, and register meaningful checks. Keep source adoption and package ownership consistent. Deploy completed changes to this PC, verify installed/source parity, shell loading, service state, launcher route, and read-only search/inventory. Perform package mutation acceptance in disposable environments; local deployment alone is not a reason to install arbitrary apps on the user's PC.
6. **Document and record acceptance.** Add the user guide, update `docs/spectrum-shell.md` and project memory, and record known limitations. Package publication follows a separate release request. No ISO build is part of this plan.

## Verification

- Backend behavior: exact-name and descriptive searches, source collisions, foreign packages, missing metadata, duplicate Flatpak scopes, stale responses, timeouts, missing tools, and malicious package/ref input.
- Transaction behavior: resolved-plan changes, concurrent Updates/external Pacman, canceled authentication, snapshot failure, unsupported snapshots, signatures, dependency providers/conflicts, full-upgrade policy, migrations, AUR review changes, split packages, build failure, and safe cancellation.
- Job lifecycle: panel close/reopen, shell restart, worker failure, interrupted transactions, and truthful per-backend outcomes.
- Native QML: keyboard-only search/install, accessible focus, narrow screens, scaled fonts, both bar orientations/styles, live palette updates, and UI responsiveness during slow backend work.
- Real disposable-environment acceptance: search/install/open through each source; user/system Flatpak distinction; real Paru build/review; pre-upgrade hooks and post-upgrade checks; no terminal requirement for installation. Use existing images or an Arch container/VM; do not build an ISO.

## Upstream references

- [Pacman command and full-upgrade semantics](https://man.archlinux.org/man/pacman.8.en)
- [Paru review and configurable command handoffs](https://github.com/Morganamilo/paru/blob/master/man/paru.conf.5)
- [libflatpak transaction API](https://docs.flatpak.org/en/latest/libflatpak-api-reference.html)
- [AUR RPC interface](https://wiki.archlinux.org/title/Aurweb_RPC_interface)

# SpectrumOS localization plan

Status: main shell/widget and UKVM control catalogs implemented; installer and additional standalone-helper integration pending, October 26, 2026. The owner confirmed Mexican/Latin American Spanish and Brazilian Portuguese as the first translations. Installer language selection and additional standalone-helper translations remain pending. This document does not authorize an ISO build or publication.

The first implementation adds a native Qt/Quickshell translator bridge, shared language registry, gettext helper, catalog compiler and isolated checks. The actual Quickshell prototype switches English → Spanish → Portuguese in place, including plural forms, while retaining a TextInput's content. The installer backend accepts independently validated `--locale` and `--region`, generates the selected target locales, supports Brazilian ABNT2, and pins machine-output parsing to `LC_ALL=C`. Time & Region exposes separate Spectrum interface and system language controls. The shell now uses shared Spanish/Portuguese catalogs across bars, widgets, menus, tooltips, shortcuts and UKVM controls, with selected native notifications translated through gettext. The main shell initializes the shared translator at startup. The graphical installer selector, additional standalone helper dialogs and third-party application/content localization remain separate work. See README.md and translations/README.md for contribution instructions. Desktop packaging builds and installs the runtime/catalogs; source installation reuses package-owned artifacts or compiles a fallback. See `translations/README.md` for build/check commands. No ISO has been rebuilt.

## First release and scope

| Display name | UI catalog locale | Suggested system locale |
| --- | --- | --- |
| English | en_US / source English | en_US.UTF-8 |
| Español (Latinoamérica) | es_MX | es_MX.UTF-8 |
| Português (Brasil) | pt_BR | pt_BR.UTF-8 |

English remains available as the fallback. Other Spanish and Portuguese locale settings should resolve through a declared base-language default when an exact catalog is unavailable; regional formatting retains the user's actual region. Add future variants as explicit catalog entries rather than silently replacing an existing translation.

The first release covers Spectrum's main shell, top/left/full/island bars, every bar profile, widgets, tooltips, empty/loading/error states, notifications and dialogs, Spectrum-owned UKVM UI, live shell, graphical installer, installation tips and recovery guidance. Include generated Thunar custom-action labels and Spectrum's file-tool dialogs/notifications. Installed application names and third-party UI use the translations supplied by their own projects. Questline task contents, notes, filenames, category names and sender-provided names/messages remain user data; Spectrum-owned labels surrounding them are translated.

## Current findings

- The shell uses Quickshell/QML. No existing translation API or catalogs were found in the inspected Spectrum sources. An initial static scan found 475 simple text/label/placeholder bindings across 44 shell files. This is a lower bound: it omits concatenated strings, dynamic menus, backend messages and independent tools.
- The GTK 4/Python installer contains hardcoded English labels, progress stages and tips. A simple scan found 41 static label/title assignments, again a lower bound.
- Time & Region already separates system language from regional formats. `scripts/time-region-adapter` generates UTF-8 locales and applies LANG/LC_MESSAGES plus separate regional LC_* categories, with sign-out guidance. It currently does not translate Spectrum's own labels.
- Before this implementation, `installer/spectrum-installer-backend` always wrote en_US.UTF-8. It now accepts validated language/region options; the graphical installer still needs to pass them. The live profile starts with C.UTF-8.
- Installer keyboard options currently cover US, Latin American Spanish, Spain and combinations; Brazilian Portuguese is absent. Its timezone list is also limited and lacks Brazilian choices.
- Installer progress currently parses English package-manager output. Changing process locale without addressing that dependency would break package-count/stage detection.
- Shell/installer/media helpers exchange machine-readable identifiers and JSON. The storage planner's confirmations and disk identity must stay independent of presentation language.

## Architecture

### Catalogs and runtime

Prefer the standard translation engines for each UI stack:

- QML: Qt Linguist catalogs, `qsTr`/`qsTranslate` and numerus forms, compiled from TS to QM.
- Python/GTK and Spectrum scripts: gettext PO/MO catalogs with contexts, named parameters and plural forms.
- A small language registry supplies supported locale codes, native display names, catalog locations and base-language fallbacks. A shared glossary aligns terminology across both catalog families.

First validate translator loading and live retranslation with the installed Quickshell version. Native Qt facilities are preferred. If Quickshell does not expose the necessary catalog loading/retranslation lifecycle, provide a small Spectrum QML translator bridge using public Qt APIs (`QTranslator` and `QQmlEngine::retranslate`) rather than changing Quickshell itself. Verify that choice with one shared button, one plural message, one open widget and the separate UKVM process before migrating the full interface.

Keep source English readable and available when entries are missing. If ID-based Qt translations are chosen during the spike, explicitly supply an English fallback catalog so raw translation IDs can never appear in the interface. Avoid a second hand-maintained JSON translation tree alongside TS/PO files.

Use complete messages with named/positional placeholders rather than sentence fragments. Keep distinct contexts for ambiguous words, such as the action Open and a status indicating that something is open. Translators receive context for destructive confirmations, accessibility names and technical terms. Stable identifiers, commands, shortcuts, protocol fields, filenames and filesystem/device identities stay language-independent.

### Language settings

Add a per-user interface preference with Follow system as the default. Integrate it into the existing Time & Region page instead of adding another widget. Show language choices by native names so users can recover after choosing an unfamiliar language.

Distinguish three concepts:

1. **Interface language:** Spectrum-owned labels; change them in place where supported.
2. **Regional formats:** dates, numbers, currency, measurement and first-day-of-week conventions.
3. **Keyboard layout:** an independent explicit choice.

Keep the existing system-language/application-locale controls, with clear guidance about signing out for other applications. A local shell interface override should not require root. System locale generation continues through the existing validated privileged helper.

The shell's shared language state updates all monitors, lazy-loaded widgets, notifications, common controls and independent Spectrum UI processes. Changing language preserves active timers, Questline drafts, file selections, ongoing transfers and the user's bar/profile choices. Read catalogs only on startup/language change; do not add per-widget polling, eager loading or a separate service.

### Backend messages

Return stable error/status codes plus structured arguments where UI translation is needed. Translate human-facing explanations at the presentation boundary. Avoid matching localized prose in code.

Keep disk-layout identities, plan fingerprints and confirmation hashes identical across languages. Display filesystem labels and device paths verbatim. Language switching must not change the selected disk, allocation plan, boot priority or storage-validation behavior.

Pin the locale of commands whose output is parsed, particularly pacman and storage diagnostics, to a known machine locale. Existing progress markers remain machine tokens. The installer maps stages/errors to translated descriptions while detailed raw command output remains available in its terminal log. Calculator/JSON/date parsing likewise uses canonical data; locale-specific formatting happens after parsing.

## Delivery phases

### 1. Inventory, glossary and a working translation prototype

- Inventory complete messages in main/UKVM/live QML, installer/recovery, Python/shell helpers and generated menu/launcher entries.
- Define the language registry and consistent terminology for widget, workspace, profile, focus, unallocated space, EFI and recovery.
- Prove Qt/Quickshell translator loading and in-place updates, Python gettext selection, plural forms and fallback.
- Establish extraction, catalog compilation and validation commands. Add build-only dependencies where required.

Gate: a small end-to-end example switches English → Spanish → Portuguese without restarting the shell or losing an open widget's state. The selected translation architecture and extraction workflow are documented.

### 2. Shell foundation and shared controls

- Add the shared translation service and persisted interface preference.
- Migrate common buttons, tooltips, global notifications, bars and language/region controls.
- Keep keyboard shortcut symbols stable while translating action descriptions; sort the shortcut catalog by displayed labels.
- Use explicit regional locale formatting for dates/numbers/currency. Recompute formatted labels when settings change.
- Check flexible widths, wrapping and tooltips against longer Spanish/Portuguese text without changing shared bar/frame attachment geometry or widget stacking.

Gate: top/left/full/island/minimal/detailed/gaming profiles render correctly at supported font sizes, narrow screens and fractional scaling; closed widgets acquire the new language when first opened.

### 3. Complete widgets and helper surfaces

- Translate every widget, including Focus/Questline UI, Default Apps, search, media/recording, display, updates, local services, break reminders, SpectrumDrop and file tools.
- Carry language preference into independently launched Spectrum helpers and UKVM UI.
- Regenerate managed Thunar labels when language changes, retaining exact action IDs, commands and all personal actions.
- Translate named stage/error messages; keep external command logs and user-authored content intact.

Gate: no untranslated Spectrum-owned primary controls or destructive confirmations remain in the three supported languages. Tests exercise background errors and newly opened lazy widgets, not just the home screen.

### 4. Installer language selector and target locale

- Place a persistent language selector on the initial installer screen, before disk selection, using English / Español (Latinoamérica) / Português (Brasil).
- Translate setup, partition inspection, alongside/erase choice, preservation warnings, review, progress, tips, errors and completion/recovery guidance.
- Change language in place while preserving account fields, disk/space selections and progress. Regenerate labels/dropdown displays while retaining their internal IDs.
- Synchronize the live QML bar and recovery/help presentation through the live session's language preference.
- Add a validated backend locale option. Generate English plus the selected language/region as needed, configure the target locale, and initialize the installed user's Spectrum preference consistently.
- Add Brazilian keyboard layout (`br`, ABNT2) while retaining independent keyboard selection. Replace the limited timezone list with a searchable world list, including Brazil.
- Keep the destructive confirmation's actual device identifier literal and storage safety checks independent of locale.
- Translate installation tips naturally; preserve their useful shortcut information and Questline-style humor rather than translating jokes word for word.

Gate: isolated erase and alongside plans are identical across interface languages; target locale generation is verified in temporary target trees; switching language neither starts installation nor changes selected storage.

### 5. Translation review and regression checks

- Review Spanish and Portuguese terminology, accents, grammar, capitalization and all safety-critical instructions.
- Validate missing/obsolete entries, placeholder parity, plural forms, invalid locale requests and English fallback.
- Test counts including zero/one/many and formatting of decimals, dates and currencies independently of UI language.
- Use expanded pseudo-translations to expose clipping before adding another language.
- Test live switching on multiple monitors, active Focus sessions, open editors/forms, queued transfers and newly loaded widgets.
- Verify no new animation/flicker, polling, memory growth or shell restarts are introduced by localization.
- Test installer state preservation, failure/retry dialogs, machine-log parsing, locale generation, and Portuguese keyboard/timezone choices.

Gate: English, Spanish and Portuguese meet the same functional and safety checks. User review confirms that the translations and layouts read naturally.

### 6. Packaging and release

- Compile and install catalogs with both desktop and installer/live payloads.
- Bundle the required live locales for offline language selection; measure locale/catalog size and RAM impact.
- Update source adoption, source archives, package recipes, file permissions and ISO staging paths.
- Build matching signed packages and validate installed catalog paths on a fresh target.
- Build an ISO only after the owner's explicit build instruction. Test its selector, live bar and installed language before requesting separate publication approval.

## Adding another language later

Add a registry entry, Qt/gettext catalogs and locale/keyboard metadata where appropriate; run the same extraction/validation/visual checks. Shared UI components should not need language-specific branches. Future right-to-left support requires a separate layout acceptance pass; the initial Latin-script release should use appropriate logical text alignment without pretending that an untested RTL layout is already supported.

## Reference documentation

- [Qt source translation and dynamic language changes](https://doc.qt.io/qt-6/i18n-source-translation.html)
- [Qt localization and catalog tooling](https://doc.qt.io/qt-6/localization.html)
- [Python gettext](https://docs.python.org/3/library/gettext.html)
- [GLib translated messages](https://docs.gtk.org/glib/func.dgettext.html)

## Implementation touchpoints

`configs/spectrum-shell/`, `configs/spectrum-ukvm/`, `scripts/time-region-adapter`, `scripts/system-adapter`, Spectrum-owned backend notifications/dialogs, `scripts/thunar-actions`, `scripts/thunar-productivity`, `installer/spectrum-installer`, `installer/spectrum-installer-backend`, `installer/spectrum-installer-storage`, `installer/spectrum-recovery`, `installer/live-shell.qml`, `installer/live-hyprland.lua`, `scripts/build-iso`, package recipes and the existing headless GTK/QML/installer checks.

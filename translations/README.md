# Translating SpectrumOS

The shell catalogs cover English, Mexican/Latin American Spanish and Brazilian Portuguese across Spectrum-owned bars, widgets, menus, tooltips, shortcut descriptions, UKVM controls and selected notifications. User content, application names, third-party content and raw command logs are preserved. The live bar and graphical installer share the registry and catalogs. Remaining standalone helper dialogs are separate work; these catalogs do not translate Arch packages automatically.

The repository [README contribution walkthrough](../README.md#help-translate-spectrumos) explains adding a language, dependencies, validation and pull requests.

## Source and catalog workflow

- `languages.json`: supported interface locale IDs, native names, base language, system-locale suggestion and gettext plural rule.
- `spectrum.pot`: generated source-message template, with references to QML/Python source locations.
- `<locale>.po`: the editable translations, shared by Qt and Python. Contexts distinguish ambiguous messages; for example, Spectrum's Clear action and Weather's Clear condition.
- `messages.json`: source metadata for messages selected dynamically, including enum labels and English plural forms. This is not another translation catalog. Add a string for the default Spectrum context, or an object with `source`, optional `context`, and optional `plural`.

```json
[
  "Daily",
  {"source": "Clear", "context": "Weather"},
  {"source": "%n file", "plural": "%n files"}
]
```

Run extraction after changing UI text or registering a locale:

```sh
scripts/update-translations
scripts/update-translations --check --complete es_MX pt_BR
```

The extractor uses Qt's parser for QML/JS, Python's AST (including the installer, progress stages and tips) for literal `translate`, `_`, `msg` and `plural` calls, and the dynamic-source metadata. It refreshes references and preserves existing translations. `--check` detects unextracted source messages; `--complete LOCALE` additionally requires reviewed translations and all plural forms for that language. Omit `--complete` while contributing a partial translation. Generated source files and obsolete catalog entries should be reviewed before merging.

## Writing messages

Use complete phrases with placeholders, leaving commands and persisted values stable:

```qml
label: qsTranslate("Spectrum", "Save")
text: qsTranslate("Spectrum", "Connected to %1").arg(serverName)
text: qsTranslate("Spectrum", "%n file", "", count)
```

```python
translate("Open {name}", name=filename)
plural("%n file", "%n files", count)
```

The Python helper uses the Spectrum context. Shared plural messages use `%n`; Python replaces it with the count, while Qt uses numerus translations. Add both English forms to `messages.json` for Qt plural calls. Python literal plural calls are extracted directly. Preserve `%1`, `%2`, `%n`, `{name}`, required whitespace, markup and keyboard symbols. Fuzzy or missing messages fall back to English.

For selectors backed by stored IDs, keep the model's original values. `FocusChoice.translateModel: true` translates its visible label and popup only. Never enable this for user-created names, filenames, application names or project/task titles. Match translated descriptions to stable shortcut commands and sort by their displayed labels.

## Build and check

Build dependencies: CMake, Qt 6 Core/QML development files, `qt6-tools`, a C++ compiler and `python-polib`. Runtime uses Qt's native translator and standard-library gettext, adding no service or widget polling.

```sh
scripts/build-localization --output artifacts/localization
python -m unittest tests.test_localization
scripts/check-localization --build artifacts/localization
scripts/check-shell-translations --build artifacts/localization
scripts/check-time-region-ui --build artifacts/localization
```

The compiler validates placeholders and the registered plural rule, including languages with more than two forms. It generates English fallback translations plus Qt QM and gettext MO catalogs from the same PO files. Generated TS/QM/MO files belong in build output, not source control. Qt and gettext plural ordering must both be checked when contributing a new language; the baseline UI checks exercise Spanish and Portuguese, not the wording of a new translation. Review longer labels at large font sizes and both bar orientations on a development installation.

## Runtime and packaging

The native module is `Spectrum.I18n 1.0`, singleton `Translator`, initialized once per independently launched UI root. `$XDG_CONFIG_HOME/spectrumos/language.json` contains `{"schema":1,"language":"system"}` or a registered locale ID. Follow system reads `/etc/locale.conf`; regional formatting follows `LC_TIME` independently. Changing the interface preference reuses the existing UI and keeps active state. Registry changes take effect after a normal shell restart.

Installed locations: `/usr/share/spectrumos/translations`, `/usr/lib/qt6/qml/Spectrum/I18n`, `/usr/lib/spectrumos/spectrum_i18n.py`. Desktop packaging builds and installs the runtime/catalogs; source installation reuses package-owned artifacts or builds a fallback. Tests override `SPECTRUM_LANGUAGE_FILE`, `SPECTRUM_SYSTEM_LOCALE_FILE` and `SPECTRUM_TRANSLATIONS_DIR` with private fixtures. The native proof also supports `--installed`, using private preference/locale files.

See the [localization plan](../docs/localization-plan.md) for installer and additional helper integration. No translation contribution requires building or publishing an ISO.

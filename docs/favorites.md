# Favorites

Open **Favorites** from the bar's **More** menu, search for it in the application launcher, or press **Super + Shift + V**. The shortcuts widget lists Favorites alphabetically.

Favorites uses a wider left-side panel, with categories beside the links and the default-browser selector fixed at the bottom. Links use two columns when space allows, and one on narrower screens. Categories have a wider sidebar, wrap long names, and scroll independently with space reserved beside the scrollbar.

## Find and open a portal

**TOP** shows the 24 most-used favorites across all categories. Within other categories, links also sort by launch count, then title. Search matches titles, URLs and category names across the whole collection. Long lists scroll with the mouse wheel or touchpad, or by dragging the scrollbar on the right. The scrollbar stays visible whenever the list overflows, including TOP.

Click a favorite or focus it with the keyboard and press Enter or Space. It opens through the system default browser, starting it when needed, and the panel closes after the launch is accepted. Each accepted launch from Favorites increments its count. Browser visits elsewhere and whether a page finishes loading are not tracked.

Each favorite also shows installed-browser icons before **Edit**. Click an icon to open that link in that browser, starting the browser when needed. Hover an icon to see its name, or reach it with Tab and press Enter or Space. These launches leave your default browser unchanged and count as one visit. The icon controls wrap inside the card when needed. The browser list refreshes when Favorites opens or when you use the bottom refresh button; a removed browser reports an error instead of opening a different browser.

The application fetches `/favicon.ico` from each site's origin, caches usable icons locally and shows a star when no usable icon is available. There is no third-party favicon proxy. Failed lookups are cached for a day; missing icons do not prevent opening a link.

## Create and edit

Choose **+ Favorite**, enter a title and an HTTP/HTTPS URL, and choose a category. **Save** writes the current form immediately and returns to the list after a successful save. Validation or sync errors keep the editor and draft open. Changes also autosave after a short pause. The default category is the one currently selected, or Uncategorized when viewing TOP. Category editors have the same **Save** control.

Use a link's **Edit** action to change its title, URL or category. An incomplete or invalid draft remains on the device and resumes when you reopen the widget, but does not create an invalid link on the board. The active category, search, editor and draft survive a shell restart. **Back** leaves the editor; complete the required fields before leaving if you want the link added to the board.

Choose **+ Category** to create a category, or select an existing category and use **Edit**. Category names autosave. TOP is an automatic view; TOP and Uncategorized cannot be deleted. Delete a favorite with one click on its × button; there is no confirmation. A category can be deleted only when empty: move or delete all its favorites first, then click **Delete** once. The button stays disabled while the category contains favorites, including links hidden by search. Empty-category deletion has no confirmation.

To move a favorite, drag its title onto a category in the sidebar. The destination highlights while you hover, and the move saves immediately when you drop it. Your current category stays selected; moving a link does not open it or increase its counter. TOP is an automatic ranking and cannot receive drops. Scroll the category list before dragging if the destination is out of view.

## Import and export

**Import** opens a file picker and previews the number of new links, duplicates and invalid entries. Confirm **Import** to apply it. Supported inputs are:

- Brave, Google Chrome and Firefox bookmark exports in HTML format.
- Uncompressed Firefox bookmark JSON backups and Chromium-style bookmark JSON trees.
- Homepage backup objects with favorites under `personal.links`.
- SpectrumOS Favorites exports (`format: "spectrum-favorites"`, `version: 1`, `links`).
- A JSON array of link objects.

Export bookmarks from your browser, then select the resulting HTML file with the same **Import** button. Nested browser folders become categories such as `Work / Research`; browser bookmarks start at zero opens because exports do not include Favorites launch counters. Firefox compressed `.jsonlz4` recovery backups are not supported; choose **Export Bookmarks to HTML** instead.

Browser instructions: [Brave](https://support.brave.com/hc/en-us/articles/360019782291-How-do-I-import-or-export-browsing-data), [Chrome](https://support.google.com/chrome/answer/96816), [Firefox](https://support.mozilla.org/en-US/kb/export-firefox-bookmarks-to-backup-or-transfer).

Each JSON link can contain `title`, `url`, `category` and `clickCount`. Existing Homepage icons are not executed or downloaded; site favicons are obtained separately. Other Homepage sections, including notes, tasks, account information and shared projects, are ignored.

Imports merge duplicate URLs rather than creating duplicates. Existing favorites retain their title and category, and the higher local/imported count is kept rather than summed. Importing a backup twice therefore does not inflate counters. A named TOP category from another app becomes Imported TOP so it remains distinct from the automatic view. Invalid URLs are counted and skipped.

**Export** saves a SpectrumOS Favorites JSON file containing only Favorites link data, category names and counts. The file chooser asks before replacing an existing export. Export includes neither other shell state nor browser information.

## Default browser

The bottom selector discovers installed desktop browsers, including compatible native and Flatpak entries. It displays the HTTPS default; refresh the list after installing or removing a browser. Selecting a browser updates the current user's HTTP/HTTPS and HTML associations. It does not install a browser or change any browser profile. Changing this selection is explicit; importing favorites does not change browser defaults.

## Local data

Data is stored in `$XDG_STATE_HOME/spectrumos/favorites/favorites.json` (normally `~/.local/state/spectrumos/favorites/favorites.json`). The data directory is private and the JSON file has mode 0600. Updates use an exclusive lock and atomic replacement; malformed existing data is reported and preserved rather than silently reset. Favorites and caches are user data and must not be committed or bundled as distro defaults.

Icons are stored under `$XDG_CACHE_HOME/spectrumos/favorites/` (normally `~/.cache/spectrumos/favorites/`). Removing the icon cache only causes fresh lookups.

The backend and rendered-panel tests use isolated temporary profiles:

```sh
python3 -m unittest tests.test_favorites
python3 tests/run_favorites.py
```

## Questline sync

Favorites are stored in Questline as **Portals** when a compatible CLI and an onboarded local profile are available. The first connection imports existing saved Favorites once, retaining categories and launch counts. The original JSON file remains a private local view/cache; do not edit it as a way to change synced data.

Widget changes save through Questline's transactional outbox and encrypted account sync. Other PCs using the same Questline identity receive new links, edits, moves, category changes and deletions. Per-PC launch counters merge without counting replayed sync events twice. The open widget refreshes every 2.5 seconds; desktop background sync normally polls every 5 seconds and backs off when offline. Queued changes remain local until connectivity returns. Enable Auto Sync in Questline on each PC. A restored profile requires explicitly re-enabling it.

Search, selected category, unfinished editor drafts, browser defaults and favicon caches remain device-specific. Profile switches clear the old profile's active editor and never import its cached links into the new account. A concurrent change to the same edited link asks you to refresh and retry rather than overwriting it.

`questline portals help` lists local bookmark commands. `spectrum-questline-sync.service` runs sync when the TUI is closed and respects Auto Sync and recovery holds. It does not publish a CLI release or start an ISO build. Older installations without a compatible CLI continue using their existing local Favorites until upgraded; once bound to Questline, edits require the compatible CLI.

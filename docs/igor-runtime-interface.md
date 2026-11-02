# Igor runtime extraction: API 1

Current public Stable runtime: **0.3.2-1**, published November 2, 2026 with
Desktop **1.1.29-1** and Hyprland defaults **1.0.3-1**. Winter Igor is free and
activates once during November 2–8; animation previews rest on the card bottom.
Earlier version references below describe historical milestones.


The first extraction is running on this PC through the isolated host bridge and
`spectrum-igor 0.1.4-1`. Legacy bundled runtime source has been retired from the current SpectrumOS tree;
public Git history and the private baseline preserve the original implementation. This is a
free runtime baseline, not a paid outfit release or working store.

## Repository and artifacts

- Private local source destination: `/home/gibranlp/Projects/Igor`.
- Private remote: https://github.com/gibranlp/Igor, created and verified private.
- QML module: `Spectrum.Igor`, version `1.0`; runtime version `0.1.2`.
- Package recipe: `packages/spectrum-igor/PKGBUILD`.
- Public artifact: the allowlisted free runtime, including the existing free SVGs
  and MIT notices. Private originals, integration fixtures, tests, service code,
  editable future artwork and paid packs are excluded.
- Source inventory: [igor-extraction-inventory.json](igor-extraction-inventory.json).

The recipe fetches the immutable runtime archive from the public SpectrumOS
source host and pins its SHA-256. `spectrum-desktop` declares the runtime
dependency. Public builds need no private Git credential. The runtime source
archive and signed runtime package are published. The updated desktop release
is not yet published. Package version 0.1.2 wraps runtime implementation 0.1.2 and API 1. The signed
stable runtime is still 0.1.1 until the next public package release.

## Responsibilities

| Igor runtime | SpectrumOS host |
| --- | --- |
| Character illustration, pose, blinking and gestures | Layer window and input mask |
| Routine scheduling, greetings, celebrations and naps | Media/meeting/Questline event inputs |
| Movie reactions, accessories and music notes | Monitor availability and suppression |
| Existing free seasonal outfit selection | Theme roles, fonts and scaling inputs |
| Character stages and nap animation | Bar/frame geometry and shared ShellMotion |

The character core imports QtQuick and its own module files. It has no dependency
on SpectrumOS shell QML, an account, or a network connection. The separate
`Spectrum.Igor.Desktop` module uses Quickshell for wardrobe settings I/O; the
wardrobe UI uses QtQuick Controls.
Host adapters in the private repository's `integration/spectrum-shell/` mirror the
public integration, with copies of existing shell dependencies used
only as regression fixtures. Shared shell source remains owned by SpectrumOS.

## Public runtime contract

`RuntimeInfo` is a singleton exposing `apiVersion`, `version`, `faceAsset`,
`headAsset`, the current `freeOutfitIds`, and eleven preview `animations`.

`IgorRoutine` accepts visits enabled, availability, suppression, monitor names,
blocked monitors, media playing/kind, meeting and celebration availability. Its
outputs retain the current names: visiting, napping, selectedMonitor, edge,
position, waving, gesture, musicPlaying, watching and celebrationMessage.

Methods remain `greet()`, `nap()`, `celebrate()`, `appear(edge, monitor)` and
`retreat()`. The host supplies only desktop state; account and payment state
must never gate these methods.

`IgorStage` receives geometry and appearance values explicitly. Instead of
importing `ShellMotion`, it accepts an injected `Translate` as `revealMotion`,
plus `motionProgress` and `motionActive`. It exposes `motionSurface`,
`motionViewportWidth` and `motionViewportHeight` so the public adapter can bind
SpectrumOS's existing shared motion without a circular dependency.

`IgorNapStage` retains the current geometry inputs, `hoverTarget`, `hoverBounds`,
`motionActive` and `dismissRequested`. The SpectrumOS host retains the existing
window layer, clipping, input mask and monitor ownership.

`IgorBridge.qml` dynamically loads `IgorRoutineModule.qml` and accepts only API 1.
Missing or incompatible runtimes produce a disabled companion with safe methods.
`IgorVisitorBridge.qml` loads the module-dependent layer host only when the routine
is compatible. The root shell does not statically import the optional module.
Older compatibility wrappers in the private fixtures serve baseline tests only.

## Free baseline and rights

This extraction copies the current free character and existing seasonal outfits.
The current desktop's MIT license is retained; it does not introduce new licensing
restrictions on public copies. No per-file ownership declarations were found in
the inspected Igor files. The inventory records package-level license evidence,
not a completed copyright audit. New commercial artwork terms and future runtime
source publication remain separate decisions before sales.

The website's existing playground and public branding copies remain intact.
Their current assets are inventoried for a later free-artifact export flow.
Future paid artwork must not be copied into the public website as original assets.

## Cutover gates

1. Completed: private repository and baseline commits are pushed.
2. Completed: immutable free runtime archive published and HTTPS hash verified.
3. Completed: isolated host loading and missing/incompatible runtime checks.
4. Legacy runtime files and character-specific tests retired. Avatar, installer,
   repository build order and host tests now use the packaged runtime.
5. Migration milestone: full desktop package checks passed in a clean chroot. The isolated
   Pacman upgrade removes legacy files with no ownership conflict and preserves
   preferences and avatar. At that milestone this PC ran desktop 1.1.27-1 and Igor package
   0.1.1-1; package integrity checks report no missing files. Live IPC reports
   runtimeReady=true and runtimeVersion=0.1.0; the shell service is active.
6. Current-tree source retirement is prepared as normal working-tree changes.
   Public Git history and prior free releases remain intact.
7. Wardrobe implemented with the four existing free looks and eleven live animation
   previews. Paid catalog entries show animated preview media and Buy badges;
   checkout and paid entitlement activation remain unavailable.

No ISO build, Git history rewrite, commerce service, paid content, or live checkout
is included in this extraction milestone.

## Wardrobe contract

Open the Igor widget from the widget picker, right-click Igor's bar button, or run
`spectrum-shell-open igor`. Previewing never changes the applied look. Select
**Use outfit**, **Automatic seasonal**, **Random from owned outfits**, or **No outfit**
to save a choice. Both visits and naps receive this selection. Previews work even
when desktop visits are disabled; hidden previews stop animation work and honor
reduced motion.

`Spectrum.Igor.Desktop.WardrobeState` calls `/usr/lib/igor/igor-outfits`. Its catalog
is `/usr/share/igor/catalog.json`; preferences are written atomically with a file
lock to `$XDG_CONFIG_HOME/igor/wardrobe.json` (mode 0600). Catalog access labels do
not grant ownership. The helper currently permits only the four frozen free IDs;
paid requests fail without modifying settings. Signed entitlements and downloaded
pack loading are a later phase.

Catalog version 1 contains `outfits` with `id`, `name`, `access` (`free` or `paid`),
and optional `packId`, `preview`, and `previews` (animation ID to animated media URL).
Paid preview media must be public derivatives, never original pack assets. There
are no production paid entries yet; tests use a small animated fixture. The free
export allowlist includes only the wardrobe, settings helper, free catalog, core,
and existing free artwork.

The wardrobe is deployed locally in desktop 1.1.28-1 and Igor 0.1.2-1. Full desktop
package checks passed; installed file hashes, package integrity, live previews,
and Top/Overlay layer ordering were verified. Existing preferences and avatar
were preserved. See [igor-wardrobe-verification.json](igor-wardrobe-verification.json).


## Signed pack installation (0.1.4)

The Desktop module now includes `igor_packs.py` and a pinned public sandbox
verification key. `igor-account restore` obtains account-bound signed receipts
and authenticated archives. Only bounded, verified static PNG outfit overlays
enter the catalog; installed outfits carry namespaced IDs and local asset URLs.
The character core consumes declarative selection data and never executes pack
code. Free outfits remain independent of accounts and networking.

The wardrobe exposes Restore packs and refreshes installed selection data after
restoration and account changes. Receipts currently allow seven days offline;
expired, signed-out or revoked cached ownership falls back to free seasonal
selection. First paid artwork, animation-pack format and device-session renewal
remain future work. See [pack verification](igor-pack-delivery-verification.json).


## Complete face model (0.2.0)

Model version 2 extends the original ears, eyes and nose into a complete lower
face, using a 400x216 rig. RuntimeInfo exposes modelVersion/modelWidth/modelHeight;
runtime API remains 1. The muzzle, mouth, chin and whiskers follow the head
transform. Sleepy/stretch yawns, surprised movie reactions, meeting mouth movement
and sleeping expressions complement the existing motions. All current costumes
and accessories are fitted to the extended rig. These updates remain free.

The Day of the Dead mask covers the lower face with a muzzle opening and decorated
jaw. The static face icon also includes the lower face. Existing visits and naps
use separate frame backing; standalone previews show the complete head without
an extended neck. All four shell edges retain attachment and clipping. Future
pack artwork must be fitted against this model before publication. No paid
artwork has been released or migrated. See [model verification](igor-face-model-verification.json).


## Face redesign reverted

The owner rejected the 0.2.x face redesign. Private commit `34fc8ac` restores the
original pre-redesign runtime exactly, retaining account and signed pack-delivery
features. The installed package is again `spectrum-igor 0.1.4-1`. Model version 2
and the complete-face sections above describe reverted historical work, not the
current model. The original face, existing outfits and animation proportions were
visually checked on workspace 6. No new face design is approved.

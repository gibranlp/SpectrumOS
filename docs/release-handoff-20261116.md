# November 16 package release handoff

Build and publish packages from the release PC. No ISO build is requested.

| Package | Prepared version | Changes |
| --- | --- | --- |
| spectrum-base | 1.0.4-1 | Hardware-detected Legion amplifier firmware setup, normal kernel update hook |
| spectrum-desktop | 1.1.39-1 | Timezone detection preview, Wi-Fi password recovery and saved-profile controls, widget fixes and translations |
| spectrum-igor | 0.3.5-2 | Star Trooper added to the free wardrobe and featured November 16–22 |

Pull SpectrumOS `master` and private Igor `main` before preparing sources.
Igor commit `312d05e` contains the approved six Star Trooper PNGs, free export
allowlist and weekly-default tests. The local review installation contains
additional private outfits: never use its installed catalog, runtime directory,
or wardrobe files as release input.

## Source preparation

In a clean SpectrumOS checkout, run:

```sh
bash scripts/build-source-archive --build
```

The generated archive is excluded from Git. It is deterministic and must
match the revision and checksum pinned in the base and desktop PKGBUILDs.
Keep checksum verification enabled; investigate any mismatch rather than
substituting a different source archive. Build changed packages using the
normal clean-chroot and signing workflow in `repo/README.md`.

The Igor package uses the already published, verified 0.3.4 free archive plus
the versioned `star-trooper.patch` and six explicitly listed PNG sources.
All required new inputs are committed under `packages/spectrum-igor/`.
The rest of the private outfit packs must not enter the public artifact.
The Igor repository can also export a 0.3.5 free archive with
`python3 scripts/build-free-runtime.py --output dist`; that alternative archive
is not the source pinned by the current SpectrumOS package recipe.

## Weekly default

From November 16 through November 22, 2026, each user's local date activates
Star Trooper once, using `2026-W47-star-trooper`. Previous manual selections
also receive the weekly default. Choices made after activation are preserved,
and disabled Igor visits stay disabled. Star Trooper remains free afterward.
Users who update during the week receive the outfit when their wardrobe state
refreshes; they do not need to select it manually.

## Verified before handoff

- Igor release, wardrobe and pack tests: 36 passed.
- Igor QML selection checks: 6 passed.
- SpectrumOS Igor package built with 8 passing runtime checks.
- Exported free catalog and public package contain only the approved free IDs;
  all six Star Trooper PNGs match the authoritative Igor source.
- SpectrumOS network, time/region, localization, hardware and packaging checks:
  111 passed.

Local builds are verification artifacts, not clean-chroot release provenance.
Public package publication still belongs to the release PC workflow.

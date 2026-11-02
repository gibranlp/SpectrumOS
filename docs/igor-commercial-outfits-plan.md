# Igor private development and paid outfit packs

Status: updated 2026-11-01. The private `gibranlp/Igor` repository is pushed;
Igor 0.1.2 and desktop 1.1.28 are installed locally, with a full-height animated
wardrobe and persistent free outfit selection. The free runtime artifact is
published; the updated desktop package is not publicly released. Paddle is the
selected provider, with sandbox integration preparation underway. There is no
working account, paid entitlement, download, or live payment flow yet. See
[runtime extraction](igor-runtime-interface.md) and [Paddle integration](igor-paddle-integration.md).

## Confirmed product decisions

- All future Igor development moves to a private repository.
- SpectrumOS and the base Igor remain free to use.
- Existing outfits remain free: Day of the Dead, Christmas hat, and Christmas lights.
  Existing functional accessories such as headphones and movie glasses remain free.
- Future outfit releases are sold as one-time purchases of packs. There is no
  subscription in the initial product.
- The Igor wardrobe provides live outfit/animation previews and outfit selection.
  Purchase restoration will follow account and entitlement integration.
- Paddle is the selected payment provider. Initial integration uses its sandbox.
- Keep the wardrobe menu-only for now; do not add a keyboard shortcut.
- Evaluate the existing cPanel server first for account and purchase hosting.

Recommended purchase policy: ownership of a purchased pack does not expire;
subsequent maintenance updates to that pack are included. Newly released packs are
separate purchases. Prices, pack contents, refund terms, and device policy remain
product decisions before checkout launches.

## Current implementation and migration boundary

Before extraction, Igor lived inside `configs/spectrum-shell/Igor*.qml`, `IgorOutfits.js`,
and `configs/spectrum-shell/igor/`. `IgorSeasonalOutfit.qml` chooses bundled SVGs
by local date. `shell.qml` owns the routine and supplies media, meetings, gaming,
monitor geometry, and Questline celebration events. `IgorVisitor.qml` also depends
on shared shell geometry and panel components. `IgorButton.qml` toggles visits.

`packages/spectrum-desktop/PKGBUILD` installs the shell host adapters; the separate
`spectrum-igor` package installs the character module and free SVGs. Moving files requires updating package installation,
imports, tests, asset preparation, translations, source exports, and website copies.
The website has a separate Igor playground at
`/home/gibranlp/gibranlp_site/spectrum-site`; include it in the migration inventory.

Use a private repository provisionally named `igor`, outside the SpectrumOS
checkout. Suggested directories:

- `runtime/`: animations, routines, base artwork, outfit renderer and base catalog.
- `outfits/`: paid artwork, editable originals, pack manifests and preview generation.
- `desktop/`: Igor client helper and wardrobe components.
- `service/`: account, purchase, entitlement, download and admin APIs.
- `release/`: separate free runtime and paid pack build/export jobs.
- `tests/`: animation, compatibility, package and commerce verification.

SpectrumOS retains shell integration, the widget entry point, package recipes,
public interface definitions, and integration tests. Igor-specific behavior lives
in the private repository. No private Git token or source checkout is needed to
build or install a public SpectrumOS release.

Publish a versioned, free `spectrum-igor` package and free runtime release artifact.
Initially make it a dependency of `spectrum-desktop` so existing installations
receive it automatically during migration. The shell adapter should still tolerate
an unavailable/incompatible runtime without failing the desktop session.

Expose the runtime as a namespaced QML module, provisionally `Spectrum.Igor`.
Keep SpectrumOS layer windows, stacking, frame geometry and attachment motion in
the shell; inject host state into Igor through a documented versioned interface.
Avoid a circular dependency on internal SpectrumOS QML files. Preserve current
visits, naps, media reactions, meetings, Questline celebrations, monitor behavior,
and reduced motion settings.

## Public history and licensing

Private development is separate from source availability and distribution rights.
The current desktop package carries an MIT license. Inventory copyright and
license coverage for each code and artwork source before choosing terms for
future releases; preserve applicable notices and third-party rights. Existing
public copies and source archives do not become private when files are moved.
Do not rewrite public history as a protection mechanism.

Decide explicitly whether future free runtime releases also publish source, or
only the distributable runtime. In either case grant the distribution rights
needed to bundle and mirror free Igor with SpectrumOS. Define separate commercial
terms for new paid artwork and clarify that buying a pack permits personal use,
not redistribution of the pack. Have the intended terms reviewed before sales.

## Outfit format and rendering

Create a versioned pack format before producing many new outfits. Each manifest
contains a stable pack ID, version, runtime compatibility range, outfit IDs,
labels/translations, preview images, asset hashes, anchor positions, layer order,
and supported animation states. Product IDs are stable and do not depend on titles.

V1 packs contain declarative manifests and local image assets only. They cannot
supply executable QML, JavaScript, shell commands, external asset URLs or arbitrary
paths. Use a fixed renderer owned by the trusted Igor runtime. Validate archive
paths, links, file counts, sizes and SVG features; reject script and external
references. Add signatures and hashes to published manifests and packs.

Support headwear, face accessories, neckwear, and other agreed attachment slots.
Specify collision rules for outfits versus functional headphones and glasses,
including clear precedence for meeting/media states. Test clipping, paws, blinking,
all visit orientations, naps, celebration, DPI and both bar orientations.

Preserve automatic seasonal mode and add explicit outfit selection, no outfit,
and optional random selection from owned, installed outfits. Manual selection
wins over seasonal suggestions; random selection never chooses an unowned pack.
Keep the first paid collection visually modest so compatibility is proven first.

## Accounts and ownership

Free users require no account or activation. They need not be registered or
counted individually. Signing in is optional until purchase restoration or paid
downloads are needed. Keep Igor identity separate from the Linux username,
Questline profile and SpectrumDrop pairing.

Use browser-based email sign-in and a short-lived device authorization flow for
the desktop. Display a device code/URL when browser launch is unavailable. Keep
refresh credentials in the user secret service where available; define a deliberate
fallback for systems without one. Never put credentials in command arguments,
logs, public repositories, or broadly readable configuration files.

The server stores:

| Entity | Purpose |
| --- | --- |
| Account | Stable account ID, verified email, status |
| Product and pack | Provider SKU mapping, pack IDs, versions, prices |
| Order and order item | Verified provider payment references and state |
| Entitlement | Account access to a specific pack, source order, active/revoked state |
| Processed payment event | Unique event ID and processing result for safe retries |
| Device/session | Installation keys, login sessions, device management |
| Audit event | Administrative changes, grants, refunds, recovery actions |

A displayed free/collector badge can be derived from active paid pack ownership.
It is not an authorization flag. Refunds revoke the affected pack, not every pack
an account owns. Support manually granted or gifted access with an audit trail.

Recommended initial license scope is one person using their own computers, with
no invasive hardware fingerprint or hard activation cap. Device sessions support
remote sign-out and recovery. Confirm this policy before launch.

## Payment and delivery flow

1. The user signs in and selects a pack in the wardrobe or website.
2. The backend creates hosted checkout for that account and server-known SKU.
3. A verified payment event records the order and grants that pack's entitlement.
4. The widget refreshes ownership, requests an authorized download, and installs
   the signed pack atomically under the user's data directory.
5. The user applies the outfit immediately. Reinstalling SpectrumOS restores the
   library after signing in again.

The payment provider handles payment details. The server verifies signatures,
checks the actual successful payment state, processes duplicate/concurrent events
safely, and reconciles missed events. A checkout redirect or local paid=true flag
never grants access. Handle delayed payments, partial refunds, disputes, event
reordering, provider outages and receipts before launch.

Keep provider integration behind a small adapter. Paddle is selected for one-time
outfit and animation packs. Start in its separate sandbox environment. The
private service now prepares one-time checkout creation and a signed, durable
webhook inbox. These do not grant ownership yet. Product approval, account
verification, authentication, entitlement processing, and paid pack delivery
remain launch gates.

## Offline access and limits

Free Igor and existing outfits always work offline. Purchased packs work offline
once downloaded and verified. Cache a signed ownership receipt and manifest;
revalidate when online without interrupting visits. Never require a successful
network check to start the desktop or display the free Igor.

A permanent offline purchase cannot also guarantee immediate offline refund
revocation. Recommended policy: enforce current ownership for new downloads and
updates, reconcile revocations on the next successful online sync, and accept
that copied or permanently offline assets cannot be recalled reliably. Signing
out should explain what happens to local paid packs before removing local access.

An open desktop cannot promise uncopyable outfits. Private source, authorized
downloads and signatures protect development, distribution and integrity; they
are not absolute DRM. Avoid kernel services, hardware locks or desktop-wide gates.

## Wardrobe widget

Add an Igor wardrobe entry in the widgets menu and a secondary action on the Igor
bar button; preserve the existing primary-click visits toggle.

Show a live preview plus:

- My outfits: free and purchased packs, thumbnails and current selection.
- Selection controls: Apply, None, Automatic seasonal, and Random from owned.
- Store: public previews of locked packs, price, pack contents and Buy in browser.
- Account: Sign in, Restore purchases, Refresh library, Manage devices, Sign out.
- States: Owned, Download, Installed, Active, Update available, Locked, and clear
  offline/download errors. Payment pending is distinct from payment completed.

Do not auto-open the store, interrupt normal visits with purchase prompts, or
change free Igor behavior for anonymous users. The panel uses existing shared
widget geometry and motion, remains below bars/frame, supports keyboard navigation,
translations, scaling and multi-monitor operation.

## Hosting and release separation

Use a dedicated service deployment and private object storage for paid downloads.
Public previews can be cached publicly; original paid assets cannot. Authorize
both metadata and pack downloads on the server and issue short-lived download URLs.
Separate release signing keys, payment secrets, account data and database backups
from Git and from public website files. Rate-limit sign-in and download endpoints.

Inspect the current hosting deployment, credentials and isolation before placing
customer data or payment webhooks there; do not infer production readiness from
the existing static site or historical project-memory claims.

Build separate artifacts: free runtime, public previews/catalog, and paid packs.
Use explicit export allowlists and CI leak checks across source archives, package
contents, debug bundles, website output and ISO inputs. Never put paid packs in
public pacman repositories or the free runtime artifact. Ordinary users must not
need sudo to download or switch outfits. No ISO build is part of this plan.

## Delivery phases and acceptance gates

1. Inventory and freeze the free baseline. List code, artwork, website copies,
   copyrights and imports. Finalize source/distribution terms and pack policy.
2. Extract the runtime to the private repository. Produce the free package, shell
   bridge, pinned artifact and atomic package upgrade. Ship no commerce yet.
   Gate: all existing Igor behavior and offline startup match the baseline.
3. Wardrobe milestone: four existing free looks and eleven live animation previews
   are implemented, with persistent seasonal/random/manual/no-outfit selection.
   Future paid catalog entries show Buy badges and animated derivatives. Pack
   downloading and signed entitlement activation remain pending.
   Gate: selections persist; invalid/incompatible packs safely fall back; updates
   cannot leave half-installed assets or break shell startup.
4. Implement accounts, ownership, storage, admin support and sandbox checkout.
   Gate: purchase, restore, multiple packs, duplicate webhooks, delayed payments,
   refunds, revoked sessions and offline use pass end-to-end tests.
5. Produce one small paid pack and pilot it with test users. Verify animation
   coverage, prices, receipts, backups, support and a reversible release process.
6. Launch paid sales, then expand the catalog. Monitor delivery failures and
   ownership discrepancies without collecting desktop activity.

Do not announce or accept payment for a pack before its complete delivery and
restore path works. Do not promise dates before the first migration and wardrobe
prototype establish scope.

## Remaining launch decisions

- Whether free runtime source is published at releases; exact license terms.
- First pack theme, contents, price/currency, included updates, and refund policy.
- Paddle merchant account approval, final service hosting/routing, and domain.
- Personal multi-device policy and the final offline/refund tradeoff.

## References

- [MIT license text and permissions](https://choosealicense.com/licenses/mit/).
- [Stripe checkout fulfillment](https://docs.stripe.com/checkout/fulfillment):
  verified payment processing and handling repeated fulfillment.
- [Lemon Squeezy merchant of record](https://docs.lemonsqueezy.com/help/payments/merchant-of-record).
- [Lemon Squeezy license objects](https://docs.lemonsqueezy.com/api/license-keys/the-license-key-object).
- [Lemon Squeezy webhook verification](https://docs.lemonsqueezy.com/help/webhooks/signing-requests).

Pricing proposals accepted for initial planning: outfit packs US$5.99, new
animation packs US$5.99, themed bundles US$9.99, and larger collections US$16.99.
Actual contents, provider product IDs, and launch prices remain unconfigured.
Existing animations stay free and work with each purchased outfit.

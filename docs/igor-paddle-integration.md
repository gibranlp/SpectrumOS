# Igor Paddle integration

Paddle is selected for one-time outfit and animation packs. The wardrobe remains
available through its widget picker and the existing Igor button's right-click;
no keyboard shortcut is added. Base Igor and all existing outfits/animations
remain free without an account.

Development stays in private `gibranlp/Igor`, under `service/`. Its first sandbox
milestone includes a Python 3.9+ adapter for one-time transaction creation, a
Paddle.js sandbox checkout template, a WSGI entry point, and a durable SQLite
webhook inbox. The public free runtime export excludes all service code. The
production catalog still contains no paid products.

The webhook receiver verifies Paddle's raw-body HMAC, rejects timestamps outside
a five-second tolerance, deduplicates concurrent deliveries and notification
replays, and commits events before acknowledging them. Completion and adjustment
creation/update events are retained for later processing. It does not yet grant
entitlements, process refunds, authenticate users, or provide pack downloads.
The checkout command is a trusted operator tool, not a public HTTP purchase API.
It rejects live credentials, inactive or recurring prices, and prices with trials.

The existing cPanel account reports Python 3.9.25, SQLite 3.34.1, and enabled
Passenger application hosting and CGI features. The Passenger registration was accepted but did not execute the app. The WSGI
service is now deployed through the host's CGI gateway; its health and fail-closed
HTTP responses are verified. Keep application code, secrets, and databases
outside the website document roots. The sandbox HTTP gateway is active; its webhook remains unconfigured until Paddle's actual destination secret is saved.

The owner will create a separate [Paddle sandbox account](https://sandbox-vendors.paddle.com/).
Then configure a sandbox API key, browser client token, real test product/price
IDs, default checkout page, and webhook destination secret using private server
configuration. Do not paste secrets into chat or put them in Git. Full instructions
are in the private repository's `service/README.md`.

The next implementation stages are email sign-in/device authorization, durable
server-owned checkout intents, entitlement/refund processing and reconciliation,
then signed pack delivery and wardrobe restoration. Sandbox end-to-end tests and
Paddle's live business/domain approval come before accepting real payments.

## Official references

- [Sandbox environments](https://developer.paddle.com/sdks/sandbox/)
- [Create transactions](https://developer.paddle.com/api-reference/transactions/create-transaction/)
- [Verify webhook signatures](https://developer.paddle.com/webhooks/about/signature-verification/)
- [Adjustment events and refund approval](https://developer.paddle.com/webhooks/adjustments/adjustment-updated/)

## Current sandbox checkout setup

The one-time US$5.99 sandbox price is mapped in the private server catalog.
The test checkout page is published at
https://spectrum.gibranlp.dev/igor/sandbox-checkout.html and its HTTPS content hash
matches the server file. It includes only the intended browser client-side token;
the server API key is excluded. This does not activate the public commerce API,
real payments, or outfit ownership.

The owner saved the default payment link after its API update returned 403.
The first sandbox transaction completed with US$5.99 captured, verified through
Paddle's transaction API. This proves the checkout connection, not ownership or
paid pack delivery.

## Webhook receiver deployment

The public sandbox base URL is
https://spectrum.gibranlp.dev/igor-sandbox-api. The application implementation,
configuration, and SQLite database remain outside the website root. Only its
public directory is mounted, containing a thin CGI gateway. The cPanel Passenger
registration is disabled because its route did not execute the app.

The health route returns 200 with `webhook_ready:false`. Unconfigured webhook
POSTs return 503 completely in under a second. The CGI gateway buffers bounded
request bodies before dispatch to preserve signature bytes and complete rejection
responses correctly. Private JSON configuration is reloaded per request; the
service rejects live configuration and configuration with group/other permissions.

Creating a Paddle notification destination with the current key returned 403.
The owner must create it in the sandbox dashboard, targeting
https://spectrum.gibranlp.dev/igor-sandbox-api/webhooks/paddle, subscribed to
`transaction.completed`, `adjustment.created`, and `adjustment.updated`, using
API version 1 and platform plus simulation events. Collect the actual endpoint
secret with a masked local prompt and store it privately. Actual Paddle webhook
delivery remains untested until then; no temporary secret is configured.

## Paddle delivery verified

A Paddle-generated `transaction.completed` simulation was received through the
public HTTPS endpoint, passed signature validation, returned `received:true`,
and was committed to the private inbox with state `simulation`. Simulator IDs
use `ntfsimevt_`; these are accepted separately from ordinary `evt_` payment
events and cannot enter the pending fulfillment queue. The sample transaction
is not the first real sandbox checkout transaction. No outfit ownership was
granted. Sandbox checkout and signed provider-to-server notification transport
are verified; accounts, checkout intents, entitlements, refunds, pack delivery,
and purchase restoration remain implementation work.


## Accounts and three-PC limit

Sandbox email sign-in, desktop authorization and account-bound purchases are now
implemented. The owner completed a sandbox purchase; the server verified the
order as completed and granted `sandbox-outfits` to that account. The test pack
contains no downloadable artwork. The installed desktop QML account component now reports signed in and one owned
pack, including after a shell restart.

Each account supports at most **three authorized PCs**. Pending approved device
requests reserve a slot until redeemed or expired. Browser sign-in does not count.
The account page lists authorized PCs with removal controls. Removing a PC revokes
its service session and frees a slot without removing account purchases. Reinstall
with the same email and remove the old installation if the account is full.
Expired desktop sessions no longer count; current sessions last 30 days. Session
renewal and offline paid-pack policy remain required before live launch.

The limit is enforced in serialized SQLite transactions, including simultaneous
approvals. Device revocation is account-scoped and protected by the existing
session, origin and CSRF checks. Free Igor continues without any account limit.


## Desktop CGI authentication

Apache requires `CGIPassAuth On` in the Igor public gateway configuration to pass
Authorization through CGI to WSGI. Without it, browser cookies work while desktop
bearer requests return 401. An isolated temporary test account verified HTTPS
401 before this change and 200 afterward, then was removed. The owner approved a
new PC connection; the installed helper and QML AccountState both loaded the owned
`sandbox-outfits` pack. A shell restart preserved the secure session. The private
repository includes `service/apache.htaccess` as the deployment template.

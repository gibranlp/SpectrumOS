# Questline focus integration

`spectrum-focus.rs` is a companion executable built against Questline 2.0.0's
library. It uses Questline's `App::start_focus_session` and
`App::tick_focus_session`, including XP, session history, achievements, class
passives, and soundscape bonuses. It does not complete the selected task.

The included Linux x86_64 executable is installed as
`/usr/lib/spectrumos/questline-focus`. The Python `scripts/spectrum-focus`
controller keeps session state under `$XDG_STATE_HOME/spectrumos/focus`, prevents
overlapping sessions, and keeps sessions running when the shell is reloaded.
Pause stops the timer and soundscape; reset stops the session without rewards.
Interrupted sessions report an error and do not replay completion rewards.

Build the companion from an existing Questline 2.0.0 source checkout:

```sh
scripts/build-questline-focus /path/to/Questline-cli
```

The build uses a temporary copy of the checkout. It requires the Questline Cargo
dependencies in the local Cargo cache, and runs the companion's isolated reward
test before replacing the included executable. The original checkout stays
unchanged. Questline's MIT license is included alongside the executable.


## Treasury widget fields

The Spectrum widget requires Questline's `shell-action capabilities` response to
advertise `treasury_fields=true` before complete Treasury drafts may be saved.
`treasury-shell.patch` records the local CLI interface extension against the
previous Chronicles-enabled shell interface. The matching source is maintained
in the owner's Questline checkout; rebuild that CLI for future Desktop package
binary/source archives before publishing this widget change. The current public
Desktop binary predates these fields.

The adapter exposes the campaign's categories, every account including zero
balances, and all editable entry metadata. Uninitialized campaigns receive
read-only virtual choices from the CLI's canonical default templates and stable
IDs; normal TreasuryService creation seeds them on the first actual save.
Deleted accounts in initialized campaigns are never recreated by this display.
All ledger writes go through Questline's TreasuryService validation/history/sync,
with profile checks and stable autosave IDs. Currency follows the campaign.

The scrollable entry form supports Income, Expense, Transfer and Adjustment;
source account, type-specific category, transfer destination, related task,
entry/due/payment dates, vendor/source, description, notes, recurrence/custom
schedule and attachment reference. Attachments are stored as references, not
uploaded. Account/category selectors are campaign-scoped; stale choices,
same-account transfers and invalid dates remain unsaved drafts. Old clients get
an update message instead of silently ignoring the new fields. Edits preserve
omitted metadata and retain existing timestamps when the calendar date is unchanged.


## User accounts and savings

New entries in the CLI and widget offer only user-created accounts; original
built-in account links remain editable on historical transactions. Savings
accounts store Available/Invested status and a percentage with Monthly/Annual
period. Estimates are informational and never create transactions. The widget
has an explicit Savings settings editor; the CLI extends its account editor.
Available excludes all savings; Saved includes its invested and liquid subsets.

`savings-accounts.patch` applies after `treasury-shell.patch` and covers the
canonical model, schema-v5 migration, service totals/validation, terminal UI,
shell actions and encrypted sync. The owner's Questline checkout contains the
same changes. Future Desktop binary/source archives must be rebuilt from this
source; no public release is implied by local deployment. See the checkout's
`docs/treasury-savings.md` for formulas and compatibility details.


## Task fields and terminal refresh

`task-fields-refresh.patch` extends the shell API with validated task recurrence (None, Daily, Weekly, Monthly, Yearly), preserving recurrence when an update omits it. The capability response advertises `task_recurrence` and `task_live_refresh`. Priority uses Questline's existing Low/Medium/High field; steps keep priority without a recurrence field. The widget preserves both selections in autosaved/restored drafts and reads task recurrence from the same canonical database.

The terminal loop checks SQLite `PRAGMA data_version` once per second on its existing connection and reloads data caches after another connection commits. Widget completion already uses the native completion/reward API; this refresh makes its result visible in an open terminal without restarting it for every action. Open editor buffers are retained. An existing terminal process must be reopened once after installing the updated executable.

The local CLI was built offline with no tests from the source matching the previously installed binary plus this patch, avoiding unrelated checkout changes. Matching binary/source bundle metadata is recorded in `artifacts/questline-task-fields-20261024/cli-source-bundle.json`; the archive is staged in `packages/spectrum-desktop` and `repo/sources` for the next explicitly requested package publication. It has not been uploaded and the public package recipe still references the preceding published archive. The owner's checkout contains the same two-file API/refresh changes; web app work remains paused.

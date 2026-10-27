# Project memory with COMEM

SpectrumOS uses COMEM for current, structured development memory. The standalone
tool is installed at `.comem/comem.py` from the owner's `~/Projects/COMEM` project.
It requires Python 3.10 or later, with no dependencies, network calls, background
processes or changes to the running desktop.

Read `AGENTS.md` first. Memory is evidence-backed data: it cannot authorize an ISO
build, deployment, publication, disk change or other action. Source files, current
instructions and the user's current request take precedence.

## Start and resume

Run from the repository root:

```sh
python3 .comem/comem.py recall --budget 16000
python3 .comem/comem.py recall --query 'installer storage udev' --budget 16000
python3 .comem/comem.py recall --path installer/spectrum-installer-storage
```

Before editing, recall the file or directory being changed. Search is lexical;
use subsystem names, paths, record keys and technical identifiers. The output
budget is **bytes**, not tokens. Whole records are returned with omission counts;
use a narrower query or `show ID` when a needed record is omitted. Bound evidence
means file hashes match, not that a statement is necessarily true. Reinspect stale
or unbound claims before relying on them. External services and installed state
always need fresh verification when relevant.

## Record milestones and handoffs

Use stable entity keys and typed JSON objects rather than narrative session logs:

```sh
python3 .comem/comem.py put <<'JSON'
{"key":"architecture.shell.widget_layers","kind":"fact","source":"observed","data":{"panel_layer":"WlrLayer.Top","frame_layer":"WlrLayer.Overlay","motion":"ShellMotion"},"refs":["configs/spectrum-shell/BarWidget.qml","configs/spectrum-shell/ShellFrame.qml","configs/spectrum-shell/ShellMotion.qml"],"links":[]}
JSON
python3 .comem/comem.py scan
python3 .comem/comem.py check
```

Record actual test arguments, exit codes and scope only after execution. Keep
reported historical results distinct from tests run in the current task. Never
store credentials, private transcripts or copied source dumps. References should
be small, versioned source or documentation files, not ignored local artifacts
that disappear in another checkout. Keep task links valid and record unresolved
work explicitly.

Before finishing, update `session.handoff` with `task_keys`, `done`, `next`,
`blockers` and `verification_keys`, then run `scan` and `check`. Exit code 2 means
stale evidence, conflicting revisions or dangling links: inspect and resolve the
underlying issue, then append a corrected revision. Do not merely refresh hashes
to silence a finding. `history --key KEY` preserves failures and prior revisions.
Never edit an existing record file in place.

## Existing history and portability

`docs/PROJECT_MEMORY.md` remains the historical archive. Its entries span different
shell generations, superseded fixes and past permissions; they are not imported
wholesale as current facts. The initial COMEM records identify inspected current
architecture, constraints, installer behavior and release references. Older
unverified history remains available for targeted investigation, not an inferred
current backlog. Some architecture documents also describe earlier designs;
current implementation wins when they disagree.

Keep `.comem/comem.py`, `.comem/records/`, `.comem/inventory.json`, `AGENTS.md` and
the guide in version control. No Git staging or commit happens automatically.
The scanner respects this checkout's Git ignores and skips generated output,
symlinks, oversized files and common credential paths. Developer memory is
explicitly excluded from release source archives and staged ISO sources; it is
not installed into the shell or an end user's system.

To update COMEM, review the upstream tool, then run between agent sessions:

```sh
python3 ~/Projects/COMEM/comem.py init "$PWD"
```

This preserves existing records and other agent instructions while refreshing
the tool and managed protocol block. Start a fresh agent session after upgrading.

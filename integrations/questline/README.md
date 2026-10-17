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

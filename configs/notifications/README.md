# Notification theme integration

The renderer produces a complete Dunst configuration at `${XDG_CACHE_HOME:-$HOME/.cache}/spectrumos/theme/current/dunstrc`. It includes Spectrum geometry, semantic urgency colors, palette-colored system icons, icon-theme lookup for applications, progress bars, history behavior, mouse actions, and a bounded set of safe application identity rules.

Dunst does not provide the same general include mechanism as Kitty. SpectrumOS2 therefore launches Dunst with the complete generated configuration and reloads that exact file only after atomic theme activation. Rules never invoke legacy application scripts; notification-provided actions remain available through the normal Dunst action menu.

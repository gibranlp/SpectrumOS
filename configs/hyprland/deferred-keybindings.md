# Deferred SpectrumOS keybindings

The following legacy assignments remain reserved while their SpectrumOS2 actions and frontends are designed. They are intentionally absent from `keybindings.conf` so a fresh session does not launch missing scripts.

| Binding | Legacy behavior | SpectrumOS2 dependency |
|---|---|---|
| `Super+P` | Spectrum panel | Launcher/widget architecture |
| `Ctrl+Tab` | Cycle layouts | Stable compositor action |
| `Ctrl+Shift+Tab` | Set default layout | User override/state design |
| `Super+S` | Search files | Launcher provider decision |
| `Super+B` | Wi-Fi manager | Network backend and widget |
| `Super+A` | Audio manager | PipeWire widget |
| `Super+V` | Emoji picker | Launcher provider decision |
| `Super+I` | Color picker | Safe reusable desktop action |
| `Super+G` | Password generator | Security and clipboard policy |
| `Super+X` | Session manager | Session/power frontend |
| `Print` | Screenshot workflow | Screenshot action and editor decision |

When these return, the key assignments should remain compatible unless usability testing identifies a conflict.

`Super+Shift+W` now opens the Weather widget and is no longer reserved for wallpaper generation.

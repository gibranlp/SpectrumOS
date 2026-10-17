# SpectrumDrop source provenance

SpectrumDrop is a SpectrumOS-maintained fork, built from source in this repository. It does not require the `omdrop` or `omdrop-owl` packages, their commands, a plugin manager, or code downloaded at runtime. Ordinary distribution libraries remain dependencies.

The maintained implementation incorporates these licensed sources:

| Component | Source revision | License |
|---|---|---|
| Transfer controller, receiver, identity and portal chooser | brentkearney/omdrop-plugin `3f936be7faa7f49180ab5167fa82066ef6d79891` | MIT |
| Radio lifecycle and OWL patches | t4t5/omdrop-owl `a063387fa8489b206f7d5dd8ed82b79825b1111f` | GPL-3.0-or-later |
| Userspace AWDL implementation | jedbillyb/owl `832d70f815c3d4a06a02117bf0fc5e868daa1ff0` | GPL-3.0-or-later |
| Sender, advertisements and identity helpers | brentkearney/omdrop-awdl `534f91a525337951ca19c311e53d333bd6d55100` | GPL-2.0-only |
| Radiotap parser | `94984dd829a605a2d7af55241145c159607f3b30` | ISC |

Original license texts and copyright notices are retained under `licenses/` and in source. The separate transfer/radio programs retain their component licenses. The public Apple CA certificates are verification material, not private identities.

SpectrumOS owns the command and service names, installation paths, settings migration, notifications, native widget integration and package builds. Legacy identities and destination settings are copied without overwriting existing SpectrumDrop settings. Radio profile opt-in is preserved locally during migration, and remains disabled by default for new installations. Receiver activation remains explicit and time bounded. Native AirDrop still uses AWDL Wi-Fi and Bluetooth; this fork does not turn Apple AirDrop into an Ethernet protocol.

Omarchy runtime dependency/driver installation and agent-skill installation are removed. Source builds use the distro's GoogleTest library, with no unpinned submodule fetch. Radio privilege is restricted to the root-owned SpectrumDrop helper by its own Polkit action. User transfer services retain their existing sandboxing.

The package ships the complete AWDL/radiotap C source under `/usr/share/spectrumdrop/source/awdl`, including its build files and protocol tests. Python and shell sources are installed directly. The same source is maintained in the SpectrumOS repository. Build the installed C source in a writable directory with CMake and the declared compiler, GoogleTest, libpcap, libev and libnl dependencies.

The maintained build disables strict aliasing for the legacy AWDL C/C++ union representation. Arch release flags with LTO otherwise fail three channel-rotation tests; retaining LTO with `-fno-strict-aliasing` passes all 65 AWDL checks. This is a compiler-build compatibility correction, not a protocol redesign.

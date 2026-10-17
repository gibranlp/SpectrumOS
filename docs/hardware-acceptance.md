# Hardware acceptance

SpectrumOS hardware acceptance is profile-specific. A successful test on one GPU or form factor does not imply support for another. Every release candidate records the ISO build identifier, machine model, firmware mode, selected profiles, kernel, graphics stack, and results below.

## Reference AMD desktop

Validated on 2026-09-01 with an AMD Radeon RX 9060 XT using `amdgpu`, Mesa RADV 26.2.1, and Vulkan 1.4:

- Vulkan enumerates the discrete GPU and creates a working swapchain.
- The matching 64-bit and 32-bit RADV drivers are installed; Steam exposes both architecture layers.
- GameMode 1.8.2 passes its complete upstream self-test.
- Gamescope 3.16.25 creates a nested Wayland/Xwayland session and renders `vkcube`.
- MangoHud 0.8.4 attaches to the Vulkan process and selects the correct DRM render node.
- Steam starts through UWSM, verifies its runtime, detects RADV and approximately 16 GiB VRAM, maps its store UI, and shuts down cleanly.

The desktop has no kernel backlight device. A Keychron keyboard exposes a compatibility joystick interface, but it is not accepted as a game controller.

## ISO laptop gate

These checks remain mandatory on physical laptop hardware after a SpectrumOS ISO exists:

- Boot the ISO in UEFI mode and verify the installer records the selected CPU, GPU, and laptop profiles.
- Verify automatic selection distinguishes discrete NVIDIA, NVIDIA + Intel, and NVIDIA + AMD systems; the review page must show the selected graphics profile before erasing the disk.
- Verify the internal display at native resolution, external-display hotplug, lid handling, suspend/resume, and lock/unlock after resume.
- Verify battery state and charge direction, AC transitions, brightness keys, audio/media keys, microphone mute, touchpad gestures, keyboard layout, Wi-Fi, Bluetooth, camera, and sleep inhibition.
- Verify Vulkan and the correct 32-bit Vulkan ICD for both GPUs. Hybrid profiles install Switcheroo Control and must demonstrate launching an application on the discrete GPU.
- Connect a real game controller and verify enumeration, Steam Input, buttons, axes, hotplug, disconnect, and suspend/resume behavior.
- Launch one native Vulkan title and one Proton title through Steam; repeat with GameMode, MangoHud, and Gamescope enabled.
- Reboot into the installed system, repeat the critical display/network/audio checks, and confirm there are no failed system or user units.

Intel, NVIDIA, hybrid-graphics, and laptop power acceptance remain open until tested on matching physical hardware. The VM boundary verifies installation and session integration only; it does not count as GPU, battery, brightness, suspend, controller, or radio acceptance.

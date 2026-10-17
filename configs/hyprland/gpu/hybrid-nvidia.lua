-- Installed with a hybrid "nvidia-intel"/"nvidia-amd" GPU profile. Hyprland
-- renders on the integrated GPU here (the panel is wired to it), so this
-- deliberately does NOT set GBM_BACKEND/__GLX_VENDOR_LIBRARY_NAME/
-- LIBVA_DRIVER_NAME=nvidia -- doing so would force the compositor and every
-- panel widget onto the dGPU instead of just offloading specific apps to it.
-- Use `/usr/lib/spectrumos/nvidia-offload <command>` to run one app on the
-- NVIDIA GPU via PRIME render offload instead.
hl.env("WLR_NO_HARDWARE_CURSORS", "1")

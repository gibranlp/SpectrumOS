-- Installed with the discrete-only "nvidia" GPU profile: Hyprland itself is
-- the primary (and only) GPU here, so forcing rendering onto it globally is
-- correct -- unlike on a hybrid install, there is no integrated GPU driving
-- the compositor that this would wrongly capture instead.
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
-- Works around a long-standing wlroots/nvidia cursor-corruption bug; harmless
-- to keep set even on driver versions where it's since been fixed.
hl.env("WLR_NO_HARDWARE_CURSORS", "1")

# modules/graphics/nvidia.nix
{ config, pkgs, ... }:

{
  # Enable OpenGL
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    # Modesetting is required for Wayland
    modesetting.enable = true;

    # Nvidia power management (important for laptops)
    powerManagement.enable = true;
    powerManagement.finegrained = false;

    # Use the open source kernel module (if your GPU supports it)
    # For older GPUs, set this to false
    open = false;

    # Enable the Nvidia settings menu
    nvidiaSettings = true;

    # Select the appropriate driver version
    # "stable" = production branch
    # "beta" = beta branch  
    # "vulkan_beta" = vulkan developer beta
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Kernel parameters for Nvidia + Hyprland
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
  ];

  # Environment variables for Nvidia + Wayland
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    LIBVA_DRIVER_NAME = "nvidia";
  };
}
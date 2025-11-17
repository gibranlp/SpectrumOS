# modules/graphics/amd.nix
{ config, pkgs, ... }:

{
  # Enable OpenGL
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    
    # Additional AMD drivers
    extraPackages = with pkgs; [
      amdvlk
      rocmPackages.clr.icd
    ];
    
    # For 32-bit applications
    extraPackages32 = with pkgs; [
      driversi686Linux.amdvlk
    ];
  };

  # Load amdgpu driver
  services.xserver.videoDrivers = ["amdgpu"];

  # AMD GPU specific kernel parameters
  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffffffff"
  ];

  # Environment variables for AMD + Wayland
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    DRI_PRIME = "1";
  };
}
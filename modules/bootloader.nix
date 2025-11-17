# modules/bootloader.nix
{ config, pkgs, ... }:

{
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10; # Keep last 10 generations
      editor = false; # Disable editor for security
    };
    
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };

    timeout = 5;
  };

  # Silent boot for cleaner experience
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet"
    "splash"
    "boot.shell_on_fail"
    "loglevel=3"
    "rd.systemd.show_status=false"
    "rd.udev.log_level=3"
    "udev.log_priority=3"
  ];

  # Plymouth for boot splash (we'll theme this later with SpectrumOS colors)
  boot.plymouth = {
    enable = true;
    # We'll create a custom theme later
    # theme = "spectrum";
  };

  # Note: systemd-boot itself is minimal and doesn't support wallpapers
  # BUT we can theme Plymouth (boot splash) with our colors
  # The boot menu will be clean and minimal, then Plymouth shows our themed splash
}
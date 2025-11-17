# modules/hyprland.nix
{ inputs, pkgs, ... }:

{
  # Enable Hyprland
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
    xwayland.enable = true;
  };

  # XDG Portal for screen sharing, file pickers, etc.
  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
  };

  # Polkit for privilege escalation
  security.polkit.enable = true;

  # Required packages for Hyprland
  environment.systemPackages = with pkgs; [
    # Wayland utilities
    wl-clipboard
    wl-clip-persist
    cliphist
    
    # Screenshot
    grim
    slurp
    
    # Notification daemon (we'll configure in home-manager)
    # mako or dunst
    
    # Wallpaper (we'll use one of these)
    swww
    # hyprpaper
    
    # Screen locker
    swaylock-effects
    
    # Logout menu
    wlogout
  ];

  # Enable dconf for GTK applications
  programs.dconf.enable = true;

  # Fonts (important for Waybar and terminal)
  fonts.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" "Iosevka" ]; })
    noto-fonts
    noto-fonts-emoji
    font-awesome
  ];
}
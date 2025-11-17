# modules/sddm.nix
{ pkgs, ... }:

{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    
    # We'll set up custom theme later with pywal colors
    theme = "breeze";
    
    settings = {
      Theme = {
        # Current theme is placeholder, we'll create spectrum theme
        Current = "breeze";
        CursorTheme = "breeze_cursors";
      };
    };
  };

  # Install SDDM themes package
  environment.systemPackages = with pkgs; [
    libsForQt5.qt5.qtgraphicaleffects
    libsForQt5.qt5.qtquickcontrols2
    libsForQt5.qt5.qtsvg
  ];

  # Note: We'll create a custom SDDM theme later that reads from
  # /etc/spectrum-theme/ where we'll put:
  # - current wallpaper
  # - pywal colors
  # This theme will be in the themes/ directory of our flake
}
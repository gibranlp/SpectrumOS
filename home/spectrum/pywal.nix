# home/spectrum/pywal.nix
{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    pywal
    imagemagick
    jq
  ];

  # Create necessary directories
  home.activation.pywalDirs = config.lib.dag.entryAfter ["writeBoundary"] ''
    mkdir -p ~/.cache/wal
    mkdir -p ~/.config/wal/templates
    mkdir -p ~/Pictures/Wallpapers
  '';

  # Mako notification daemon with pywal support
  services.mako = {
    enable = true;
    backgroundColor = "#1e1e2e";
    textColor = "#cdd6f4";
    borderColor = "#89b4fa";
    borderRadius = 10;
    borderSize = 2;
    defaultTimeout = 5000;
    width = 300;
    height = 100;
    margin = "10";
    padding = "10";
    font = "JetBrainsMono Nerd Font 10";
    
    extraConfig = ''
      [urgency=high]
      border-color=#f38ba8
    '';
  };

  # Create pywal templates directory structure
  home.file.".config/wal/templates/colors-hyprland.conf".text = ''
    $background = rgb({background.strip})
    $foreground = rgb({foreground.strip})
    $color0 = rgb({color0.strip})
    $color1 = rgb({color1.strip})
    $color2 = rgb({color2.strip})
    $color3 = rgb({color3.strip})
    $color4 = rgb({color4.strip})
    $color5 = rgb({color5.strip})
    $color6 = rgb({color6.strip})
    $color7 = rgb({color7.strip})
    $color8 = rgb({color8.strip})
    $color9 = rgb({color9.strip})
    $color10 = rgb({color10.strip})
    $color11 = rgb({color11.strip})
    $color12 = rgb({color12.strip})
    $color13 = rgb({color13.strip})
    $color14 = rgb({color14.strip})
    $color15 = rgb({color15.strip})
  '';

  home.file.".config/wal/templates/colors-waybar.css".text = ''
    @define-color background {background};
    @define-color foreground {foreground};
    @define-color color0 {color0};
    @define-color color1 {color1};
    @define-color color2 {color2};
    @define-color color3 {color3};
    @define-color color4 {color4};
    @define-color color5 {color5};
    @define-color color6 {color6};
    @define-color color7 {color7};
    @define-color color8 {color8};
    @define-color color9 {color9};
    @define-color color10 {color10};
    @define-color color11 {color11};
    @define-color color12 {color12};
    @define-color color13 {color13};
    @define-color color14 {color14};
    @define-color color15 {color15};
  '';

  home.file.".config/wal/templates/colors-rofi.rasi".text = ''
    * {{
        background: {background};
        foreground: {foreground};
        color0: {color0};
        color1: {color1};
        color2: {color2};
        color3: {color3};
        color4: {color4};
        color5: {color5};
        color6: {color6};
        color7: {color7};
        color8: {color8};
        color9: {color9};
        color10: {color10};
        color11: {color11};
        color12: {color12};
        color13: {color13};
        color14: {color14};
        color15: {color15};
    }}
  '';

  home.file.".config/wal/templates/colors-mako".text = ''
    background-color={background}
    text-color={foreground}
    border-color={color4}
    
    [urgency=high]
    border-color={color1}
  '';

  home.file.".config/ranger/rc.conf".text = ''
    set preview_images true
    set preview_images_method kitty
    set colorscheme default
'';
}

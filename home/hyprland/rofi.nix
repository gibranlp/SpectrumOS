programs.rofi = {
  enable = true;
  package = pkgs.rofi-wayland;
  
  extraConfig = {
    modi = "drun,run,window";
    show-icons = true;
    terminal = "kitty";
    drun-display-format = "{icon} {name}";
    sidebar-mode = true;
  };
};

# Use a separate rasi file for theming
home.file.".config/rofi/config.rasi".text = ''
  @import "~/.cache/wal/colors-rofi.rasi"
  
  * {
    bg-col: @background;
    bg-col-light: @color0;
    border-col: @color4;
    selected-col: @color4;
    fg-col: @foreground;
    width: 600;
  }
  
  window {
    height: 360px;
    border: 3px;
    border-color: @border-col;
    background-color: @bg-col;
    border-radius: 10px;
  }
'';

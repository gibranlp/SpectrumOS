# home/hyprland/kitty.nix
{ config, pkgs, ... }:

{
  programs.kitty = {
    enable = true;
    
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 11;
    };

    settings = {
      # Window
      window_padding_width = 10;
      background_opacity = "0.9";
      background_blur = 1;
      
      # Cursor
      cursor_shape = "beam";
      cursor_beam_thickness = "1.5";
      
      # Performance
      repaint_delay = 10;
      input_delay = 3;
      sync_to_monitor = true;
      
      # Mouse
      copy_on_select = true;
      
      # Tab bar
      tab_bar_edge = "bottom";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";
      
      # Shell
      shell = "zsh";
      
      # Scrollback
      scrollback_lines = 10000;
      
      # URLs
      url_style = "curly";
      open_url_with = "default";
      
      # Confirm close
      confirm_os_window_close = 0;
    };

    # Pywal will override these colors automatically!
    # Kitty reads from ~/.cache/wal/colors-kitty.conf
    # We just need to include it in extraConfig
    extraConfig = ''
      # Import pywal colors
      include ~/.cache/wal/colors-kitty.conf
    '';
  };
}
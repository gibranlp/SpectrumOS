# home/hyprland/rofi.nix
{ config, pkgs, ... }:

{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    terminal = "kitty";
    
    extraConfig = {
      modi = "drun,run,window";
      show-icons = true;
      drun-display-format = "{icon} {name}";
      display-drun = "  Apps";
      display-run = "  Run";
      display-window = "  Window";
    };
  };

  # Custom rofi theme with pywal
  home.file.".config/rofi/theme.rasi".text = ''
    * {
        background:     #1e1e2eff;
        background-alt: #313244ff;
        foreground:     #cdd6f4ff;
        selected:       #89b4faff;
        active:         #a6e3a1ff;
        urgent:         #f38ba8ff;
    }

    @import "~/.cache/wal/colors-rofi-dark.rasi"

    window {
        transparency:                "real";
        location:                    center;
        anchor:                      center;
        width:                       600px;
        border-radius:               10px;
        background-color:            @background;
    }

    mainbox {
        enabled:                     true;
        spacing:                     10px;
        padding:                     20px;
        background-color:            transparent;
        children:                    [ "inputbar", "listview" ];
    }

    inputbar {
        enabled:                     true;
        spacing:                     10px;
        padding:                     8px;
        border-radius:               5px;
        background-color:            @background-alt;
        text-color:                  @foreground;
        children:                    [ "prompt", "entry" ];
    }

    prompt {
        enabled:                     true;
        background-color:            @selected;
        text-color:                  @background;
        padding:                     8px;
        border-radius:               5px;
    }

    entry {
        enabled:                     true;
        padding:                     8px;
        background-color:            transparent;
        text-color:                  @foreground;
        placeholder:                 "Search...";
        placeholder-color:           inherit;
    }

    listview {
        enabled:                     true;
        columns:                     1;
        lines:                       8;
        cycle:                       true;
        dynamic:                     true;
        scrollbar:                   false;
        layout:                      vertical;
        reverse:                     false;
        spacing:                     5px;
        background-color:            transparent;
    }

    element {
        enabled:                     true;
        padding:                     8px;
        border-radius:               5px;
        background-color:            transparent;
        text-color:                  @foreground;
    }

    element selected.normal {
        background-color:            @selected;
        text-color:                  @background;
    }

    element-icon {
        background-color:            transparent;
        size:                        32px;
    }

    element-text {
        background-color:            transparent;
        text-color:                  inherit;
        vertical-align:              0.5;
        horizontal-align:            0.0;
    }
  '';
}
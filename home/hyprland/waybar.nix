# home/hyprland/waybar.nix
{ config, pkgs, ... }:

{
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 34;
        spacing = 4;

        modules-left = [ "hyprland/workspaces" "hyprland/window" ];
        modules-center = [ "clock" ];
        modules-right = [ "pulseaudio" "network" "cpu" "memory" "temperature" "battery" "tray" ];

        "hyprland/workspaces" = {
          format = "{icon}";
          format-icons = {
            "1" = "1";
            "2" = "2";
            "3" = "3";
            "4" = "4";
            "5" = "5";
            "6" = "6";
            "7" = "7";
            "8" = "8";
            "9" = "9";
            "10" = "10";
          };
          persistent-workspaces = {
            "*" = 5;
          };
        };

        "hyprland/window" = {
          max-length = 50;
          separate-outputs = true;
        };

        clock = {
          format = "{:%H:%M}";
          format-alt = "{:%A, %B %d, %Y (%R)}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "year";
            mode-mon-col = 3;
            weeks-pos = "right";
            on-scroll = 1;
            format = {
              months = "<span color='#ffead3'><b>{}</b></span>";
              days = "<span color='#ecc6d9'><b>{}</b></span>";
              weeks = "<span color='#99ffdd'><b>W{}</b></span>";
              weekdays = "<span color='#ffcc66'><b>{}</b></span>";
              today = "<span color='#ff6699'><b><u>{}</u></b></span>";
            };
          };
        };

        cpu = {
          format = " {usage}%";
          tooltip = false;
        };

        memory = {
          format = " {}%";
        };

        temperature = {
          critical-threshold = 80;
          format = "{icon} {temperatureC}°C";
          format-icons = [ "" "" "" ];
        };

        battery = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-charging = " {capacity}%";
          format-plugged = " {capacity}%";
          format-alt = "{icon} {time}";
          format-icons = [ "" "" "" "" "" ];
        };

        network = {
          format-wifi = " {essid}";
          format-ethernet = " wired";
          format-linked = " {ifname} (No IP)";
          format-disconnected = "⚠ Disconnected";
          format-alt = "{ifname}: {ipaddr}/{cidr}";
          tooltip-format = "{ifname} via {gwaddr}";
        };

        pulseaudio = {
          format = "{icon} {volume}%";
          format-bluetooth = "{icon} {volume}%";
          format-bluetooth-muted = " {icon}";
          format-muted = " {volume}%";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [ "" "" "" ];
          };
          on-click = "pavucontrol";
        };

        tray = {
          spacing = 10;
        };
      };
    };

    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background: transparent;
      }

      #workspaces {
        background: @background;
        margin: 5px;
        padding: 0px 5px;
        border-radius: 10px;
      }

      #workspaces button {
        padding: 0px 5px;
        color: @foreground;
        border-radius: 10px;
      }

      #workspaces button.active {
        background: @color4;
        color: @background;
      }

      #workspaces button:hover {
        background: @color1;
        color: @background;
      }

      #window,
      #clock,
      #battery,
      #cpu,
      #memory,
      #temperature,
      #network,
      #pulseaudio,
      #tray {
        background: @background;
        padding: 0px 10px;
        margin: 5px 0px;
        border-radius: 10px;
      }

      #clock {
        color: @color6;
        font-weight: bold;
      }

      #battery {
        color: @color2;
      }

      #battery.charging {
        color: @color3;
      }

      #battery.warning:not(.charging) {
        color: @color5;
      }

      #battery.critical:not(.charging) {
        color: @color1;
        animation: blink 0.5s linear infinite;
      }

      #cpu {
        color: @color4;
      }

      #memory {
        color: @color5;
      }

      #temperature {
        color: @color3;
      }

      #temperature.critical {
        color: @color1;
      }

      #network {
        color: @color6;
      }

      #network.disconnected {
        color: @color1;
      }

      #pulseaudio {
        color: @color7;
      }

      #pulseaudio.muted {
        color: @foreground;
      }

      #tray {
        padding: 0px 5px;
      }

      @keyframes blink {
        to {
          background-color: @color1;
          color: @background;
        }
      }

      /* Pywal colors will be imported here */
      @import "~/.cache/wal/colors-waybar.css";
    '';
  };
}
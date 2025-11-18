# home/common.nix
{ config, pkgs, pkgs-unstable, inputs, ... }:

{
  imports = [
    ./hyprland/hyprland.nix
    ./hyprland/waybar.nix
    ./hyprland/kitty.nix
    ./hyprland/rofi.nix
    ./spectrum/pywal.nix
    ./creative/gimp.nix
    ./creative/kdenlive.nix
  ];

  home.username = "gibranlp";
  home.homeDirectory = "/home/gibranlp";
  home.stateVersion = "24.11";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Git configuration
  programs.git = {
    enable = true;
    userName = "gibranlp";
    userEmail = "root@gibranlp.dev";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = false;
    };
  };

  # Zsh configuration
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    
    shellAliases = {
      ll = "ls -la";
      spectrum-update = "sudo nixos-rebuild switch --flake ~/SpectrumOS#spectrum-laptop";
      spectrum-colors = "~/SpectrumOS/scripts/spectrum-update.sh";
      update = "nix flake update ~/SpectrumOS && spectrum-update";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "sudo" "docker" "kubectl" ];
      theme = "robbyrussell";
    };
  };

  # Development tools
  home.packages = with pkgs; [
    # Essential tools
    btop
    neofetch
    ripgrep
    fd
    eza
    bat
    fzf
    
    # Development
    vscode
    nodejs_20
    python312
    python312Packages.pip
    
    # File managers
    ranger
    yazi
    xfce.thunar
    xfce.thunar-volman
    xfce.thunar-archive-plugin
        
    # Image viewers
    feh
    imv
    
    # Development Tools
    docker
    docker-compose
    
    #Communication
    telegram-desktop
    discord
    whatsapp-for-linux
    
    # Utilities
    bitwarden
    thefuck
    transmission_4
    wget
    curl
    yt-dlp    
    hugo

    # PDF viewer
    zathura
    
    # Web browsers
    firefox
    
    # Pywal and dependencies
    pywal
    imagemagick
    
    # Screenshot tools
    grim
    slurp
    swappy

    # Archiving tools
    file-roller
    unzip
    unrar
    p7zip
  ];

  # GTK theme (will be synced with pywal later)
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Breeze_Snow";
      package = pkgs.libsForQt5.breeze-gtk;
      size = 24;
    };
  };

  # Qt theme
  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "adwaita-dark";
  };
}

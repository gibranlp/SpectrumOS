# modules/sddm.nix
{ pkgs, config, ... }:

let
  spectrumTheme = pkgs.stdenv.mkDerivation {
    name = "sddm-spectrum-theme";
    src = ../themes/sddm/spectrum-theme;
    installPhase = ''
      mkdir -p $out/share/sddm/themes/spectrum-theme
      cp -r $src/* $out/share/sddm/themes/spectrum-theme/
    '';
  };
in
{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "spectrum-theme";
  };

  environment.systemPackages = with pkgs; [
    spectrumTheme
    libsForQt5.qt5.qtgraphicaleffects
    libsForQt5.qt5.qtquickcontrols2
    libsForQt5.qt5.qtsvg
  ];

  system.activationScripts.sddmThemeWritable = ''
    chmod -R 755 /run/current-system/sw/share/sddm/themes/spectrum-theme/
  '';
}
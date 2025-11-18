# modules/sddm.nix
{ pkgs, config, ... }:

let
  spectrumTheme = pkgs.stdenv.mkDerivation {
    name = "sddm-spectrum-theme";
    src = ../themes/sddm/spectrum-theme;
    installPhase = ''
      mkdir -p $out/share/sddm/themes/spectrum-theme
      cp -r $src/* $out/share/sddm/themes/spectrum-theme/
      
      # Replace Colors.qml with a symlink to writable location
      rm -f $out/share/sddm/themes/spectrum-theme/Colors.qml
      ln -sf /var/lib/sddm/.cache/spectrum/Colors.qml $out/share/sddm/themes/spectrum-theme/Colors.qml
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

  # Create writable directory for colors
  system.activationScripts.sddmColorsDir = ''
    mkdir -p /var/lib/sddm/.cache/spectrum
    chown -R sddm:sddm /var/lib/sddm/.cache
    
    # Create default Colors.qml if doesn't exist
    if [ ! -f /var/lib/sddm/.cache/spectrum/Colors.qml ]; then
      cat > /var/lib/sddm/.cache/spectrum/Colors.qml << 'EOF'
pragma Singleton
import QtQuick 2.11
QtObject {
    readonly property string background: "#1e1e2e"
    readonly property string foreground: "#cdd6f4"
    readonly property string color1: "#f38ba8"
    readonly property string color2: "#a6e3a1"
    readonly property string color3: "#f9e2af"
    readonly property string color4: "#89b4fa"
}
EOF
      chmod 644 /var/lib/sddm/.cache/spectrum/Colors.qml
    fi
  '';
}
# home/creative/kdenlive.nix
{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    kdenlive
    ffmpeg-full
    mediainfo
    # Additional codecs and tools
    libsForQt5.kio-extras
  ];
}
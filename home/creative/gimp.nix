# home/creative/gimp.nix
{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    gimp
    gimpPlugins.gmic
  ];
}
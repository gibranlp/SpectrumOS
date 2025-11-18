# modules/docker.nix
{ config, pkgs, ... }:

{
  # Enable Docker
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  # Add your user to docker group
  users.users.gibranlp.extraGroups = [ "docker" ];
}

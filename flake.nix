{
  description = "SpectrumOS - A color-spectrum themed NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    hyprland.url = "github:hyprwm/Hyprland";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, hyprland, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
    in
    {
      # Laptop configuration (Nvidia)
      nixosConfigurations.spectrum-laptop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { 
          inherit inputs pkgs-unstable;
          hostname = "spectrum-laptop";
        };
        modules = [
          ./hosts/laptop/default.nix
          ./modules/bootloader.nix
          ./modules/hyprland.nix
          ./modules/graphics/nvidia.nix
          ./modules/sddm.nix
	  ./modules/docker.nix
          
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.gibranlp = import ./home/common.nix;
            home-manager.extraSpecialArgs = { 
              inherit inputs pkgs-unstable;
            };
          }
        ];
      };

      # Desktop configuration (AMD) - for later
      nixosConfigurations.spectrum-desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { 
          inherit inputs pkgs-unstable;
          hostname = "spectrum-desktop";
        };
        modules = [
          ./hosts/desktop/default.nix
          ./modules/bootloader.nix
          ./modules/hyprland.nix
          ./modules/graphics/amd.nix
          ./modules/sddm.nix
          
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.gibranlp = import ./home/common.nix;
            home-manager.extraSpecialArgs = { 
              inherit inputs pkgs-unstable;
            };
          }
        ];
      };
    };
}

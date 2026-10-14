{
  description = "Unofficial Nix flake for the native Linux Epic Games Launcher (Preview)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        # Allow just this package rather than every unfree package
        config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "epic-games-launcher";
      };
    in
    {
      packages.${system} = {
        default = self.packages.${system}.epic-games-launcher;
        epic-games-launcher = pkgs.callPackage ./package.nix { };
      };

      # Builds against whatever nixpkgs the consumer applies the overlay to
      overlays.default = final: _prev: {
        epic-games-launcher = final.callPackage ./package.nix { };
      };

      nixosModules.default = import ./module.nix;

      # nix run .#update: bump package.nix to Epic's current .deb build
      apps.${system}.update = {
        type = "app";
        program = nixpkgs.lib.getExe (
          pkgs.writeShellApplication {
            name = "update";
            runtimeInputs = with pkgs; [
              coreutils
              dpkg
              gawk
              gnugrep
              gnused
              jq
            ];
            text = builtins.readFile ./update.sh;
          }
        );
        meta.description = "Update package.nix to Epic's current .deb build";
      };
    };
}

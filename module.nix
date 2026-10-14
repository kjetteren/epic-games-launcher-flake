{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.epic-games-launcher;
in
{
  options.programs.epic-games-launcher = {
    enable = lib.mkEnableOption "Epic Games Launcher Preview";

    package = lib.mkOption {
      type = lib.types.package;
      # Built against the host's own pkgs (its nixpkgs pin, overlays and config),
      # not a second nixpkgs instance from this flake.
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalMD "`epic-games-launcher` from this flake, built against the system's `pkgs`";
      description = "The Epic Games Launcher package to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    # mkDefault so a host can still set these differently without a conflict
    hardware.graphics = {
      enable = lib.mkDefault true;
      enable32Bit = lib.mkDefault true;
    };
  };
}

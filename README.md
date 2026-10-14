# Epic Games Launcher for NixOS

[![Update launcher](https://github.com/kjetteren/epic-games-launcher-flake/actions/workflows/update.yml/badge.svg)](https://github.com/kjetteren/epic-games-launcher-flake/actions/workflows/update.yml)

An unofficial Nix flake for the native Linux Epic Games Launcher (Preview). It packages Epic's official `.deb` and runs it with system libraries from nixpkgs, so the store, video and audio work. Windows games run through GE-Proton, which the launcher sets up itself.

The flake provides a package, an overlay and a NixOS module, for `x86_64-linux` only.

## Quick try

```sh
nix run github:kjetteren/epic-games-launcher-flake
```

## NixOS module

Add the flake as an input and enable the module:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    epic-games-launcher = {
      url = "github:kjetteren/epic-games-launcher-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, epic-games-launcher, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      modules = [
        ./configuration.nix
        epic-games-launcher.nixosModules.default
        {
          programs.epic-games-launcher.enable = true;
        }
      ];
    };
  };
}
```

The launcher is unfree, so your configuration has to allow it, either with `nixpkgs.config.allowUnfree = true;` or with a predicate:

```nix
nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "epic-games-launcher" ];
```

| Option | Default | Description |
| --- | --- | --- |
| `programs.epic-games-launcher.enable` | `false` | Install the launcher. Also enables `hardware.graphics` and its 32-bit support, as defaults you can override. |
| `programs.epic-games-launcher.package` | built from this flake with your `pkgs` | The package to install. |

## Overlay

To use the package elsewhere, for example in Home Manager:

```nix
nixpkgs.overlays = [ epic-games-launcher.overlays.default ];
home.packages = [ pkgs.epic-games-launcher ];
```

## How it works

Epic's `.deb` contains only the launcher binary, Epic's own EOS SDK library, icons and a desktop entry. The package unpacks it unmodified and runs it in an FHS environment (`buildFHSEnv`) that provides WebKitGTK, GTK, GStreamer and the rest from nixpkgs. GE-Proton, which the launcher downloads on first game launch, runs inside the same environment.

## Updates

Epic's download link always redirects to the newest build's own URL. `package.nix` pins that URL rather than the link, so a locked version keeps building after Epic releases a newer one, as long as Epic keeps the old build online. A GitHub Actions workflow checks the link daily. When it points to a new build, the workflow updates `package.nix`, builds the package and commits the result. To pick up new builds, update the flake input:

```sh
nix flake update epic-games-launcher
```

The launcher's built-in updater doesn't apply under Nix.

If a new build changes the `.deb`'s dependencies or file layout, the workflow stops without committing. Those changes would still build but break the launcher at runtime, so they need a manual look.

To update by hand from a checkout, run `nix run .#update`.

A second workflow moves `flake.lock` to the latest nixpkgs every week, if the package still builds with it. The NixOS module and the overlay build with your own nixpkgs instead, so this mainly matters for `nix run`.

## Known issues

- **Playtime isn't published.** The launcher logs `No machine id available` and keeps playtime locally. This appears to be a limitation of Epic's Linux preview.
- **Controllers:** Proton logs `Failed loading SDL3 library.` (from sdl2-compat), so Wine uses its own controller backends instead of SDL.
- **Quit the launcher after the game has fully exited.** The launcher records the session and uploads cloud saves when Proton exits, a few seconds after the game window closes. Quitting earlier postpones the upload until the next start.

## Where things live

- **Launcher data, GE-Proton and Wine prefixes:** `~/.local/share/com.epicgames.eglv2`
- **Games:** `~/Games` by default

## How this was made

This flake was written with an AI assistant (Claude). I directed it, tested every change on my own NixOS machine and debugged problems from the launcher's logs, but most of the code came from the assistant, so it's fair to call it vibe-coded. If something breaks or looks wrong, issues and pull requests are welcome.

## Disclaimer

This project isn't affiliated with or endorsed by Epic Games. Epic Games and Epic Games Launcher are trademarks of Epic Games, Inc. The launcher is proprietary software. This repository contains only Nix code, and Nix downloads the launcher from Epic's servers when you build it.

## License

The Nix code in this repository is licensed under the [MIT License](LICENSE). That license doesn't cover the Epic Games Launcher itself, which is proprietary and governed by Epic's [end user license agreement](https://legal.epicgames.com/store/eula).

{
  lib,
  stdenvNoCC,
  fetchurl,
  dpkg,
  buildFHSEnv,
  appimageTools,
}:

let
  pname = "epic-games-launcher";
  version = "0.96.0";

  # Epic's .deb ships only its own files: the launcher binary, the EOS SDK
  # library in /usr/lib/epic-games-launcher, icons and a desktop file. Every
  # system library comes from nixpkgs through the FHS env below.
  unwrapped = stdenvNoCC.mkDerivation {
    pname = "${pname}-unwrapped";
    inherit version;

    # The URL of this exact build, which Epic's download link redirects to.
    # The link itself always serves the newest build.
    src = fetchurl {
      url = "https://content-download-egs.distro.on.epicgames.com/Builds/EGLv2/0.96.0%2Bg2fade97/Linux/EpicGamesLauncher-x86_64.deb";
      hash = "sha256-fL1Z5hiDeTN1tsgk8SptB/diPuutZ/qQaIAaEr57vQQ=";
    };

    # dpkg's setup hook unpacks the .deb into ./root
    nativeBuildInputs = [ dpkg ];

    dontConfigure = true;
    dontBuild = true;
    # Use Epic's binaries exactly as shipped: no stripping, no RPATH changes
    dontFixup = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r usr/. $out/
      runHook postInstall
    '';
  };
in
buildFHSEnv {
  inherit pname version;

  targetPkgs =
    pkgs:
    appimageTools.defaultFhsEnvArgs.targetPkgs pkgs
    ++ (with pkgs; [
      # Puts /usr/lib/epic-games-launcher (EOS SDK, resources) in the FHS env
      unwrapped

      # The .deb's Depends (GTK 3 is already in the defaults) plus libsoup,
      # which the binary links directly
      webkitgtk_4_1
      libayatana-appindicator
      libsoup_3

      # WebKit: TLS backend, GSettings backend, and GStreamer plugins
      # (good: autoaudiosink/pulsesink, libav: H.264/AAC trailers)
      glib-networking
      dconf
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-ugly
      gst_all_1.gst-libav

      # Required by GE-Proton's `proton` startup script & Wine prefix setup
      python3
      bash
      coreutils
      findutils
      file
      gnugrep
      gnused
      gawk
      which
      util-linux
      procps
      pciutils
      xrandr
      zenity

      # Other launcher & Proton/Wine dependencies
      curl
      gamemode
      libnotify
      nss
      openssl
      vulkan-loader
      vulkan-tools
      wayland
      xdg-utils
      freetype
      fontconfig
      alsa-lib
      alsa-plugins
      libpulseaudio
      pipewire
      libGL
      libxkbcommon
      sdl3
      sdl2-compat
    ]);

  multiPkgs = appimageTools.defaultFhsEnvArgs.multiPkgs;

  # nixpkgs' GLib only searches its own module directory, so point it at the
  # FHS one: glib-networking (TLS for the store) and dconf live there.
  #
  # The launcher's self-updater only handles .deb and AppImage installs. Under
  # Nix it fails, showing an update-failed dialog whenever the installed
  # version differs from Epic's current release, so switch it off: updates
  # come through this flake.
  profile = ''
    export GIO_EXTRA_MODULES=/usr/lib/gio/modules
    export EGL_DISABLE_SELF_UPDATE=1
  '';

  runScript = "${unwrapped}/bin/EpicGamesLauncher";

  extraInstallCommands = ''
    install -m 444 -D ${unwrapped}/share/applications/epic-games-launcher.desktop \
      $out/share/applications/epic-games-launcher.desktop

    substituteInPlace $out/share/applications/epic-games-launcher.desktop \
      --replace-fail 'Exec=EpicGamesLauncher' 'Exec=${pname}'

    cp -r ${unwrapped}/share/icons $out/share/
  '';

  # unwrapped: the unpacked .deb, e.g. nix build .#default.unwrapped
  passthru = { inherit unwrapped; };

  meta = {
    description = "Native Epic Games Launcher Preview for Linux";
    homepage = "https://launcher.epicgames.com/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "epic-games-launcher";
  };
}

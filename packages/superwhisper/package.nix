# Adapted from zicochaos/omarchy-nix pkgs/superwhisper.nix (MIT); launcher,
# setup script and unit come from omacom/omarchy-pkgs pkgbuilds/superwhisper-bin.
{
  lib,
  stdenv,
  fetchurl,
  fetchFromGitHub,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook4,
  gobject-introspection,
  minisign,
  zstd,
  python3,
  gtk4,
  gtk4-layer-shell,
  at-spi2-core,
  librsvg,
  gdk-pixbuf,
  fontconfig,
  fcitx5,
  vulkan-loader,
  wayland,
  libglvnd,
  libnotify,
  pulseaudio,
  wl-clipboard,
  ffmpeg,
  foot,
  xdg-utils,
  systemd,
  procps,
  coreutils,
  gnugrep,
}:

let
  recipes = fetchFromGitHub {
    owner = "omacom";
    repo = "omarchy-pkgs";
    rev = "49a75e027eba101a9cbdff59dc74c695725219cc";
    hash = "sha256-NeJSjeXL29D8HAkgjm01C9ysSVVhzKg5mkTiC0rJmVQ=";
  };
  recipe = "${recipes}/pkgbuilds/superwhisper-bin";
  python = python3.withPackages (ps: [
    ps.pygobject3
    ps.pycairo
  ]);
  version = "1.2.0";
  arch = stdenv.hostPlatform.parsed.cpu.name;
  hashes = {
    x86_64 = {
      tarball = "sha256-KLxXWO1s9CRouX75QOwqlrEU5rbqA7yywEvGeIV9AvA=";
      signature = "sha256-tN/JRwzgRaltPprCrFvlp+q1v7wXqphjVeiwZzIj4vI=";
    };
    aarch64 = {
      tarball = "sha256-sA448gPdW4xjS3bf2VwxEoWP3myQTniKN0GYHA6uafg=";
      signature = "sha256-glzUF39kShm9J3mhLKJvitg1trLpB22JbVvn+gY31KM=";
    };
  };
  sums = hashes.${arch} or (throw "superwhisper: unsupported architecture ${arch}");
  url = "https://tux.superwhisper.com/${arch}/v${version}/superwhisper-omarchy-${arch}-${version}.tar.zst";
in
stdenv.mkDerivation {
  pname = "superwhisper";
  inherit version;

  src = fetchurl {
    inherit url;
    hash = sums.tarball;
  };
  signature = fetchurl {
    url = "${url}.minisig";
    hash = sums.signature;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook4
    gobject-introspection
    minisign
    zstd
    python
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    gtk4
    gtk4-layer-shell
    at-spi2-core
    librsvg
    gdk-pixbuf
    fontconfig
    fcitx5
    vulkan-loader
  ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  preUnpack = ''
    minisign -Vm "$src" -x "$signature" -p "${recipe}/linux-release.pub"
  '';

  postPatch = ''
    test "$(cat VERSION)" = '${version}'
    # The shell loads this plugin outside the CLI's wrapped environment.
    substituteInPlace app/assets/omarchy-plugin/superwhisper-panel/Service.qml \
      --replace-fail '"python3"' '"${python3}/bin/python3"'
    # Qt 6.12 adds a Color type that shadows the shell's palette singleton.
    python3 - app/assets/omarchy-plugin/superwhisper-panel <<'PY'
    from pathlib import Path
    import re
    import sys

    for path in Path(sys.argv[1]).glob("*.qml"):
        original = path.read_text()
        updated = re.sub(r"(?<![\w.])Color\b", "Commons.Color", original)
        if updated != original:
            alias = r"(?m)^import qs\.Commons(?: [0-9.]+)? as Commons[ \t]*$"
            if not re.search(alias, updated):
                updated, imports = re.subn(
                    r"(?m)^(import qs\.Commons(?: [0-9.]+)?[ \t]*)$",
                    r"\1\nimport qs.Commons as Commons", updated, count=1)
                if imports != 1:
                    raise SystemExit(f"Cannot qualify palette import in {path}")
            if len(re.findall(alias, updated)) != 1 or re.search(r"(?<![\w.])Color\b", updated):
                raise SystemExit(f"Invalid palette references in {path}")
            path.write_text(updated)
    PY
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/superwhisper/app" "$out/bin"
    cp -a app/. "$out/share/superwhisper/app/"
    rm -f "$out/share/superwhisper/app/scripts/omarchy-menu-rows.py" \
      "$out/share/superwhisper/app/scripts/update.py" \
      "$out/share/superwhisper/app/uninstall.sh"
    install -Dm755 "${recipe}/superwhisper" "$out/bin/superwhisper"
    install -Dm755 "${recipe}/setup-user" "$out/share/superwhisper/setup-user"
    install -Dm644 "${recipe}/superwhisper.service" "$out/lib/systemd/user/superwhisper.service"
    install -Dm644 "${recipe}/superwhisper.desktop" "$out/share/applications/superwhisper.desktop"
    install -Dm644 "${recipe}/superwhisper-url.desktop" "$out/share/applications/superwhisper-url.desktop"

    substituteInPlace "$out/bin/superwhisper" \
      --replace-fail '/opt/superwhisper' "$out/share/superwhisper/app"
    substituteInPlace "$out/share/superwhisper/setup-user" \
      --replace-fail '/opt/superwhisper' '/run/current-system/sw/share/superwhisper/app' \
      --replace-fail '/usr/bin/superwhisper' '/run/current-system/sw/bin/superwhisper' \
      --replace-fail 'with pacman;' 'with NixOS generations;'
    substituteInPlace "$out/lib/systemd/user/superwhisper.service" \
      --replace-fail '/usr/bin/superwhisper' "$out/bin/superwhisper"
    substituteInPlace "$out/share/applications/superwhisper.desktop" \
      --replace-fail 'Exec=foot ' 'Exec=${foot}/bin/foot ' \
      --replace-fail 'superwhisper settings' "$out/bin/superwhisper settings"
    substituteInPlace "$out/share/applications/superwhisper-url.desktop" \
      --replace-fail 'Exec=superwhisper ' "Exec=$out/bin/superwhisper "

    install -Dm644 -t "$out/share/licenses/superwhisper/" licenses/*
    install -Dm644 README.md "$out/share/doc/superwhisper/README.md"
    install -Dm644 app/assets/linux-status/SuperwhisperTUI.ttf \
      "$out/share/fonts/superwhisper/SuperwhisperTUI.ttf"
    for size in 16 32 64 128 256 512 1024; do
      install -Dm644 "app/assets/app-icon/$size.png" \
        "$out/share/icons/hicolor/''${size}x''${size}/apps/superwhisper.png"
    done
    mkdir -p "$out/share/fcitx5/addon"
    substitute app/assets/fcitx5/superwhisper.conf.in "$out/share/fcitx5/addon/superwhisper.conf" \
      --replace-fail '@LIBRARY@' "$out/share/superwhisper/app/lib/fcitx5/libsuperwhisper-fcitx5"
    patchShebangs "$out/bin" "$out/share/superwhisper"

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          gtk4-layer-shell
          vulkan-loader
          wayland
          libglvnd
        ]
      }
      --prefix PATH : ${
        lib.makeBinPath [
          python
          pulseaudio
          wl-clipboard
          libnotify
          ffmpeg
          fontconfig
          foot
          xdg-utils
          systemd
          procps
          coreutils
        ]
      }
    )
    wrapProgram "$out/share/superwhisper/setup-user" \
      --prefix PATH : "$out/bin:${
        lib.makeBinPath [
          coreutils
          gnugrep
          systemd
          xdg-utils
        ]
      }"
  '';

  meta = {
    description = "Local and cloud voice dictation";
    homepage = "https://superwhisper.com";
    license = [
      lib.licenses.unfree
      lib.licenses.mit
    ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    hydraPlatforms = [ ];
    mainProgram = "superwhisper";
  };
}

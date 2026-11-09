# Hex voice dictation by Anomaly (github.com/anomalyco/hex). Named hex-dictation
# because nixpkgs `hex` is an unrelated hex dump tool. Recipe follows
# omacom/omarchy-pkgs pkgbuilds/hex-bin.
{
  lib,
  stdenv,
  fetchurl,
  fetchFromGitHub,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  curl,
  libx11,
  libxcb,
  libxcursor,
  libxi,
  libxkbcommon,
  openblas,
  vulkan-loader,
  wayland,
  wl-clipboard,
  wtype,
  xdg-utils,
}:
let
  version = "3.3.0";
  recipe = fetchFromGitHub {
    owner = "omacom";
    repo = "omarchy-pkgs";
    rev = "49a75e027eba101a9cbdff59dc74c695725219cc";
    hash = "sha256-NeJSjeXL29D8HAkgjm01C9ysSVVhzKg5mkTiC0rJmVQ=";
  };
  sources = {
    x86_64-linux = {
      sha256 = "e8c7b3a2ebeb1d7da5d6276d5f25145891d52178e3636347cb3ac331f7662622";
    };
    aarch64-linux = {
      sha256 = "a8a28cb8bc922f8e11fd5996e090d88aa143a2c3a65b07f1962435d0b15a24d1";
    };
  };
  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "hex-dictation: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "hex-dictation";
  inherit version;

  src = fetchurl {
    url = "https://anoma.ly/release/hex/files/${source.sha256}/hex";
    inherit (source) sha256;
  };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    alsa-lib
    curl
    libx11
    libxcb
    libxcursor
    libxi
    libxkbcommon
    openblas
    vulkan-loader
    wayland
  ];

  # The X11/Wayland/xkbcommon client libraries and OpenBLAS are dlopen'd.
  runtimeDependencies = [
    libxkbcommon
    openblas
    vulkan-loader
    wayland
    libx11
    libxcb
    libxcursor
    libxi
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/hex
    wrapProgram $out/bin/hex --prefix PATH : ${
      lib.makeBinPath [
        wl-clipboard
        wtype
        xdg-utils
      ]
    }

    install -Dm644 ${recipe}/pkgbuilds/hex-bin/hex.desktop $out/share/applications/hex.desktop
    install -Dm644 ${recipe}/pkgbuilds/hex-bin/hex.service $out/lib/systemd/user/hex.service
    install -Dm644 ${recipe}/pkgbuilds/hex-bin/LICENSE $out/share/licenses/hex-dictation/LICENSE
    substituteInPlace $out/share/applications/hex.desktop --replace-fail /usr/bin/hex $out/bin/hex
    substituteInPlace $out/lib/systemd/user/hex.service --replace-fail /usr/bin/hex $out/bin/hex

    runHook postInstall
  '';

  meta = {
    description = "Hex voice dictation app by Anomaly: hold a key, speak, and it types";
    homepage = "https://github.com/anomalyco/hex";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames sources;
    mainProgram = "hex";
  };
}

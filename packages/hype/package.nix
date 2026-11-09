# Adapted from olafkfreund/nixarchy pkgs/apps/hype.nix (MIT).
{
  lib,
  stdenv,
  fetchFromGitHub,
  qt6,
  ffmpeg,
  sourceHighlight,
  zlib,
  libwebp,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "hype";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "omacom";
    repo = "hype";
    tag = "v${finalAttrs.version}";
    hash = "sha256-lDrDfo0LqGbWD8X7rejOYf9nKqyNNZh6wMlL9wRRJoU=";
  };

  nativeBuildInputs = [
    qt6.qmake
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtmultimedia
    qt6.qtsvg
    qt6.qtimageformats
    zlib
    libwebp
  ];

  qtWrapperArgs = [
    "--prefix PATH : ${
      lib.makeBinPath [
        ffmpeg
        sourceHighlight
      ]
    }"
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 hype $out/bin/hype
    install -Dm644 $src/pkgbuild/hype.desktop \
      $out/share/applications/hype.desktop
    install -Dm644 $src/pkgbuild/hype.svg \
      $out/share/icons/hicolor/scalable/apps/hype.svg
    install -Dm644 $src/LICENSE $out/share/licenses/hype/LICENSE

    runHook postInstall
  '';

  meta = {
    description = "Simple Markdown presentations with a visual slide editor";
    homepage = "https://github.com/omacom/hype";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "hype";
  };
})

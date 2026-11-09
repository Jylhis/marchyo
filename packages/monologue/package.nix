# Adapted from olafkfreund/nixarchy pkgs/apps/monologue.nix (MIT).
{
  lib,
  stdenv,
  fetchFromGitHub,
  qt6,
  pkg-config,
  ffmpeg,
  libpulseaudio,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "monologue";
  version = "0.3.1";

  src = fetchFromGitHub {
    owner = "omacom";
    repo = "monologue";
    tag = "v${finalAttrs.version}";
    hash = "sha256-sQm/n0kHl13JQ3iOcOM5rZcP9xqrPpw6EKTVBLWha/I=";
  };

  nativeBuildInputs = [
    qt6.qmake
    qt6.wrapQtAppsHook
    pkg-config
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtmultimedia
    libpulseaudio
  ];

  qtWrapperArgs = [ "--prefix PATH : ${lib.makeBinPath [ ffmpeg ]}" ];

  installPhase = ''
    runHook preInstall

    install -Dm755 monologue $out/bin/monologue
    install -Dm644 $src/pkgbuild/monologue.desktop \
      $out/share/applications/monologue.desktop
    install -Dm644 $src/pkgbuild/monologue.svg \
      $out/share/icons/hicolor/scalable/apps/monologue.svg
    install -Dm644 $src/LICENSE $out/share/licenses/monologue/LICENSE

    runHook postInstall
  '';

  meta = {
    description = "Theme-synced webcam recorder";
    homepage = "https://github.com/omacom/monologue";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "monologue";
  };
})

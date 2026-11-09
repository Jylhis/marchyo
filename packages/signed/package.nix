# Adapted from olafkfreund/nixarchy pkgs/apps/signed.nix (MIT).
{
  lib,
  stdenv,
  fetchFromGitHub,
  qt6,
  pkg-config,
  kdePackages,
  qpdf,
  nss,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "signed";
  version = "0.3.1";

  src = fetchFromGitHub {
    owner = "omacom";
    repo = "signed";
    tag = "v${finalAttrs.version}";
    hash = "sha256-fH5jXdO0uNsRblramzU0lcP3Dvv7pMZjf41FdE3lKjY=";
  };

  nativeBuildInputs = [
    qt6.qmake
    qt6.wrapQtAppsHook
    pkg-config
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtwayland
    kdePackages.poppler
    qpdf
  ];

  qtWrapperArgs = [ "--prefix PATH : ${lib.makeBinPath [ nss.tools ]}" ];

  installPhase = ''
    runHook preInstall

    install -Dm755 signed $out/bin/signed
    install -Dm644 $src/pkgbuild/signed.desktop \
      $out/share/applications/signed.desktop
    install -Dm644 $src/pkgbuild/signed.svg \
      $out/share/icons/hicolor/scalable/apps/signed.svg
    install -Dm644 $src/LICENSE $out/share/licenses/signed/LICENSE

    runHook postInstall
  '';

  meta = {
    description = "Sign PDFs and fill them in with text and dates";
    homepage = "https://github.com/omacom/signed";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "signed";
  };
})

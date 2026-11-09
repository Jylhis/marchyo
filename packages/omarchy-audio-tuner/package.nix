# Recipe follows omacom/omarchy-pkgs pkgbuilds/omarchy-audio-tuner.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  bash,
  python3,
  ffmpeg,
  mpv,
  libpulseaudio,
  lsp-plugins,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "omarchy-audio-tuner";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "omacom-io";
    repo = "omarchy-audio-tuner";
    tag = "v${finalAttrs.version}";
    hash = "sha256-B0K3J7FUlpVR2Cv9nndBXv/z6+ZymbDDkRJPzDaqveI=";
  };

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [
    bash
    python3
  ];

  dontConfigure = true;
  dontBuild = true;

  # The tools call each other by relative path, so the tree is installed intact
  # and one wrapper puts the command on PATH.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/omarchy-audio-tuner $out/bin
    cp -a measure fit generate compare $out/share/omarchy-audio-tuner/
    install -Dm755 omarchy-audio-tuner $out/share/omarchy-audio-tuner/omarchy-audio-tuner
    patchShebangs $out/share/omarchy-audio-tuner

    makeWrapper $out/share/omarchy-audio-tuner/omarchy-audio-tuner $out/bin/omarchy-audio-tuner \
      --prefix PATH : ${
        lib.makeBinPath [
          ffmpeg
          mpv
          libpulseaudio
        ]
      } \
      --set-default LV2_PATH ${lsp-plugins}/lib/lv2

    install -Dm644 README.md $out/share/doc/omarchy-audio-tuner/README.md
    install -Dm644 LICENSE $out/share/licenses/omarchy-audio-tuner/LICENSE

    runHook postInstall
  '';

  meta = {
    description = "Tools for authoring laptop speaker tunings";
    homepage = "https://github.com/omacom-io/omarchy-audio-tuner";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "omarchy-audio-tuner";
  };
})

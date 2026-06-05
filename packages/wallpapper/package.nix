{
  lib,
  stdenv,
  swift,
  swiftpm,
  apple-sdk_14,
  src,
}:

stdenv.mkDerivation {
  pname = "wallpapper";
  version = "1.7.4";

  inherit src;

  nativeBuildInputs = [
    swift
    swiftpm
  ];

  buildInputs = [ apple-sdk_14 ];

  configurePhase = ''
    runHook preConfigure
    export HOME=$TMPDIR
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    swift build --disable-sandbox --configuration release
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm0755 .build/release/wallpapper $out/bin/wallpapper
    install -Dm0755 .build/release/wallpapper-exif $out/bin/wallpapper-exif
    runHook postInstall
  '';

  meta = {
    description = "Generator for macOS dynamic HEIC wallpapers";
    homepage = "https://github.com/mczachurski/wallpapper";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
    mainProgram = "wallpapper";
  };
}

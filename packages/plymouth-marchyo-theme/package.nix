{
  stdenvNoCC,
  lib,
  ...
}:
stdenvNoCC.mkDerivation {
  pname = "plymouth-marchyo-theme";
  version = "v3.0.0";
  src = ./.;

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/plymouth/themes/marchyo
    cp * $out/share/plymouth/themes/marchyo
    find $out/share/plymouth/themes/ -name \*.plymouth -exec sed -i "s@\/usr\/@$out\/@" {} \;
    runHook postInstall
  '';
  meta = {
    description = "Marchyo splash screen. Forked from https://github.com/basecamp/marchyo/tree/2df8c5f7e0a2aafb8c9aacb322408d2ed7682ea5";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}

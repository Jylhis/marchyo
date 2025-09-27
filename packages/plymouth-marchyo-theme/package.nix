{
  stdenvNoCC,
  fetchFromGitHub,
  lib,
  ...
}:
stdenvNoCC.mkDerivation rec {
  pname = "plymouth-omarchy-theme";
  version = "v3.0.0";
  src = ./.;

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/plymouth/themes/omarchy
    cp * $out/share/plymouth/themes/omarchy
    find $out/share/plymouth/themes/ -name \*.plymouth -exec sed -i "s@\/usr\/@$out\/@" {} \;
    runHook postInstall
  '';
  meta = {
    description = "Marchyo splash screen. Forked from https://github.com/basecamp/omarchy/tree/2df8c5f7e0a2aafb8c9aacb322408d2ed7682ea5";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}

{
  stdenvNoCC,
  lib,
  ...
}:
stdenvNoCC.mkDerivation {
  pname = "plymouth-marchyo-theme";
  version = "3.0.0";
  src = ./.;

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/plymouth/themes/marchyo
    # Copy the theme assets only — not this package.nix, which lives alongside
    # them in the source directory.
    find . -maxdepth 1 -type f ! -name package.nix \
      -exec cp {} $out/share/plymouth/themes/marchyo \;
    find $out/share/plymouth/themes/ -name \*.plymouth -exec sed -i "s@\/usr\/@$out\/@" {} \;
    runHook postInstall
  '';
  meta = {
    description = "Marchyo splash screen. Forked from https://github.com/basecamp/marchyo/tree/2df8c5f7e0a2aafb8c9aacb322408d2ed7682ea5";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}

# Build website as a static site
{ pkgs, ... }:

pkgs.stdenv.mkDerivation {
  name = "marchyo-website";
  src = ./.;

  buildPhase = ''
    # No build needed for static HTML
  '';

  installPhase = ''
    mkdir -p $out
    cp -r index.html $out/
    cp -r css $out/
    cp -r js $out/
    cp -r assets $out/ 2>/dev/null || true

    echo "Website built successfully"
    ls -la $out
  '';
}

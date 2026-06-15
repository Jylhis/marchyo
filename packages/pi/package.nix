# pi — Armin Ronacher's minimal terminal coding agent (earendil-works/pi).
#
# Packaged from the published npm tarball (@earendil-works/pi-coding-agent), whose
# `bin` is a bundled `dist/cli.js`, so it runs under node with no extra
# node_modules. If a future version unbundles its dependencies this wrapper would
# need a buildNpmPackage with an npmDepsHash instead.
{
  lib,
  stdenvNoCC,
  fetchurl,
  nodejs,
  makeWrapper,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "pi";
  version = "0.79.3";

  src = fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${finalAttrs.version}.tgz";
    hash = "sha512-B3rAyw4/f1l3EYjQpCKpevzuBIPjYor6fHxPHQpLMdn/NTv3536i1P4ZrsyFkKpXqJWH66xKK5hyf8sqRe3dGA==";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/pi"
    cp -r . "$out/lib/pi/"
    makeWrapper ${lib.getExe nodejs} "$out/bin/pi" \
      --add-flags "$out/lib/pi/dist/cli.js"
    runHook postInstall
  '';

  meta = {
    description = "Minimal terminal coding agent";
    homepage = "https://pi.dev";
    license = lib.licenses.mit;
    mainProgram = "pi";
    maintainers = [ ];
    platforms = lib.platforms.all;
  };
})

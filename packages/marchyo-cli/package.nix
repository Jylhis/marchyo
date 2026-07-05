{
  lib,
  stdenvNoCC,
  bun,
  ...
}:
let
  # Bun's lockfile-driven offline install.
  # The hash needs to be regenerated whenever bun.lock changes:
  #   1. set this to lib.fakeHash
  #   2. run `nix build .#marchyo-cli` and copy the suggested hash back here
  nodeModules = stdenvNoCC.mkDerivation {
    pname = "marchyo-cli-node-modules";
    version = "0.1.0";
    src = ./.;
    nativeBuildInputs = [ bun ];
    dontConfigure = true;
    buildPhase = ''
      runHook preBuild
      export HOME="$NIX_BUILD_TOP"
      bun install --frozen-lockfile --no-progress
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r node_modules $out/
      runHook postInstall
    '';
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-c3MEHCrrYskHCLzJNkJDb7nuL5HXmz4nkWpG1NwpiRo=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "marchyo-cli";
  version = "0.1.0";
  src = ./.;
  nativeBuildInputs = [ bun ];
  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    cp -r ${nodeModules}/node_modules ./node_modules
    chmod -R u+w ./node_modules
    export HOME="$NIX_BUILD_TOP"

    bun build --compile \
      packages/user-cli/src/cli.tsx --outfile marchyo
    bun build --compile \
      packages/dev-cli/src/cli.tsx --outfile marchyoctl

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 marchyo $out/bin/marchyo
    install -Dm755 marchyoctl $out/bin/marchyoctl
    runHook postInstall
  '';

  meta = {
    description = "Marchyo CLI utilities — `marchyo` (user) and `marchyoctl` (developer)";
    homepage = "https://github.com/jylhis/marchyo";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    mainProgram = "marchyo";
  };
}

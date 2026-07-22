{
  lib,
  stdenvNoCC,
  bun,
  ...
}:
let
  inherit (builtins.fromJSON (builtins.readFile ./package.json)) version;
  # Bun's lockfile-driven offline install.
  # The hash needs to be regenerated whenever bun.lock changes:
  #   1. set this to lib.fakeHash
  #   2. run `nix build .#marchyo-cli` and copy the suggested hash back here
  nodeModules = stdenvNoCC.mkDerivation {
    pname = "marchyo-cli-node-modules";
    inherit version;
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
  inherit version;
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

    # Completions + man page come from the binary itself (generated off the
    # live commander tree), so they can never drift from the real surface.
    ./marchyo completion bash > marchyo.bash
    ./marchyo completion zsh > _marchyo
    ./marchyo completion fish > marchyo.fish
    ./marchyo completion man > marchyo.1
    install -Dm644 marchyo.bash $out/share/bash-completion/completions/marchyo
    install -Dm644 _marchyo $out/share/zsh/site-functions/_marchyo
    install -Dm644 marchyo.fish $out/share/fish/vendor_completions.d/marchyo.fish
    install -Dm644 marchyo.1 $out/share/man/man1/marchyo.1
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

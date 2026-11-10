{
  lib,
  stdenvNoCC,
  bun,
  dconf,
  dbus,
  makeWrapper,
  ...
}:
let
  inherit (builtins.fromJSON (builtins.readFile ./package.json)) version;
  # The working tree as git would see it: no dev state or bun install output.
  src = lib.cleanSourceWith {
    name = "marchyo-cli";
    src = ./.;
    filter =
      path: type:
      let
        base = baseNameOf path;
      in
      lib.cleanSourceFilter path type
      && !(builtins.elem base [
        "node_modules"
        ".direnv"
        ".env"
      ])
      && !lib.hasPrefix ".devenv" base;
  };
  # Bun's lockfile-driven offline install.
  # The hash needs to be regenerated whenever bun.lock changes:
  #   1. set this to lib.fakeHash
  #   2. run `nix build .#marchyo-cli` and copy the suggested hash back here
  nodeModules = stdenvNoCC.mkDerivation {
    pname = "marchyo-cli-node-modules";
    inherit version src;
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
      cp -r --reflink=auto node_modules $out/
      runHook postInstall
    '';
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-JsMCJT2nuajAyrwtyiZgaA41kj17JoaUJWeApwFu0jU=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "marchyo-cli";
  inherit version;
  inherit src;
  nativeBuildInputs = [
    bun
    makeWrapper
  ];
  nativeInstallCheckInputs = [ dbus ];
  doInstallCheck = true;
  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    cp -r --reflink=auto ${nodeModules}/node_modules ./node_modules
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
    wrapProgram $out/bin/marchyo --prefix PATH : ${lib.makeBinPath [ dconf ]}

    # String catalogs the compiled binary reads from ../share/marchyo/i18n
    # (the shell package ships the same tree).
    mkdir -p $out/share/marchyo/i18n
    cp -r ${../../shell/i18n}/. $out/share/marchyo/i18n/
    chmod -R u+w $out/share/marchyo/i18n

    # `marchyo whats-new` reads the release notes from ../share/marchyo.
    install -Dm644 ${../../NEWS} $out/share/marchyo/NEWS
    install -Dm644 ${../../CHANGELOG.md} $out/share/marchyo/CHANGELOG.md

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

  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$PWD/check-home"
    export XDG_CONFIG_HOME="$HOME/config"
    export XDG_STATE_HOME="$HOME/state"
    export XDG_DATA_HOME="$HOME/data"
    export XDG_DATA_DIRS="${dconf}/share"
    export MARCHYO_GREETER_THEME_DIR="$HOME/greeter"
    unset HYPRLAND_INSTANCE_SIGNATURE
    mkdir -p "$HOME/light" "$XDG_DATA_HOME/marchyo/themes"
    touch "$HOME/light/gtk.css"
    cat > "$XDG_DATA_HOME/marchyo/themes/manifest.json" <<EOF
    {"themes":[],"defaultTheme":{"name":"light","variant":"light","dir":"$HOME/light"}}
    EOF
    dbus-run-session --config-file=${dbus}/share/dbus-1/session.conf -- ${stdenvNoCC.shell} -c \
      'PATH=/nonexistent exec "$1" runtime restore' _ "$out/bin/marchyo"
    test "$(readlink "$XDG_CONFIG_HOME/marchyo/current-theme")" = "$HOME/light"
    test "$(${dconf}/bin/dconf read /org/gnome/desktop/interface/color-scheme)" = "'prefer-light'"
    runHook postInstallCheck
  '';

  meta = {
    description = "Marchyo CLI utilities — `marchyo` (user) and `marchyoctl` (developer)";
    homepage = "https://github.com/jylhis/marchyo";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "marchyo";
  };
}

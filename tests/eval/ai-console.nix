# Evaluation tests for modules/home/ai-console.nix (Quake console, herdr) and
# modules/nixos/ai-tools.nix (herdr and Amp packages).
{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers)
    withTestUser
    testNixOSCheck
    testNixOSFails
    hyprHasBind
    hyprEntriesText
    ;

  evalWith =
    extra:
    lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        (withTestUser (
          lib.recursiveUpdate {
            marchyo.desktop.enable = true;
            home-manager.users.testuser.imports = [ homeManagerModules ];
          } extra
        ))
      ];
    };

  hmFor = eval: eval.config.home-manager.users.testuser;
  hypr = hm: hm.wayland.windowManager.hyprland;
  binds = hm: (hypr hm).settings.bind or [ ];
  hasUnit = hm: n: hm.systemd.user.services ? ${n};
  hasSystemPackage = cfg: n: lib.any (p: lib.getName p == n) cfg.environment.systemPackages;

  # Every chord bound more than once across the generated bind list.
  duplicateChords =
    hm:
    let
      chords = lib.filter (c: c != null) (map (e: builtins.head (e._args or [ null ])) (binds hm));
      counts = lib.foldl' (acc: c: acc // { ${c} = (acc.${c} or 0) + 1; }) { } chords;
    in
    lib.attrNames (lib.filterAttrs (_: n: n > 1) counts);
  consoleChords = [
    "SUPER + grave"
    "SUPER + SHIFT + grave"
    "SUPER + CTRL + return"
  ];

  mkVerifyConfig =
    name: extra:
    let
      eval = evalWith extra;
      hm = hmFor eval;
      hyprlandConfig = hm.xdg.configFile."hypr/hyprland.lua".source;
      inherit ((hypr hm)) package;
    in
    pkgs.runCommand name { nativeBuildInputs = [ package ]; } ''
      export XDG_RUNTIME_DIR="$(mktemp -d)"
      log=$(mktemp)
      ${package}/bin/hyprland --verify-config --config ${hyprlandConfig} 2>&1 | tee "$log"
      grep -q -F 'config ok' "$log" || { echo "FAIL: no 'config ok'" >&2; exit 1; }
      if grep -E -i -e 'invalid dispatcher' -e '^\s*error' -e 'parse error' \
           -e 'attempt to (call|index) a nil value' -e 'lua error' -e 'error loading' "$log"; then
        echo "FAIL: hyprland --verify-config reported errors" >&2
        exit 1
      fi
      touch $out
    '';
in
{
  # Desktop default: the console rule, workspace logic, seed command and binds.
  eval-console-default =
    let
      hm = hmFor (evalWith { });
      lua = (hypr hm).extraConfig;
      rules = hyprEntriesText ((hypr hm).settings.window_rule or [ ]);
    in
    pkgs.writeText "eval-console-default" (
      if
        hyprHasBind (binds hm) "SUPER + grave" "toggle_special(\"qconsole\")"
        && hyprHasBind (binds hm) "SUPER + SHIFT + grave" "special:qconsole"
        && lib.hasInfix "special:qconsole" lua
        && lib.hasInfix "local box = 2" lua
        && lib.hasInfix "AI_AGENT" lua
        && lib.hasInfix "org\\.marchyo\\.console" rules
        && lib.hasInfix "special:qconsole silent" rules
        && !(hyprHasBind (binds hm) "SUPER + CTRL + return" "herdr")
      then
        "pass"
      else
        throw "FAIL: console defaults missing a bind, rule or Lua piece"
    );

  # The console binds are free chords: nothing else is bound to them.
  eval-console-no-duplicate-binds =
    let
      hm = hmFor (evalWith {
        marchyo.ai.herdr.enable = true;
      });
    in
    pkgs.writeText "eval-console-no-duplicate-binds" (
      if lib.intersectLists consoleChords (duplicateChords hm) == [ ] then
        "pass"
      else
        throw "FAIL: a console or herdr chord is bound twice"
    );

  eval-console-disabled =
    let
      hm = hmFor (evalWith {
        marchyo.console.enable = false;
      });
    in
    pkgs.writeText "eval-console-disabled" (
      if
        !(hyprHasBind (binds hm) "SUPER + grave" "qconsole")
        && !(lib.hasInfix "qconsole" (hypr hm).extraConfig)
      then
        "pass"
      else
        throw "FAIL: console.enable = false still configures the console"
    );

  # herdr off by default: no service, no package.
  eval-herdr-default-off =
    let
      eval = evalWith { };
      hm = hmFor eval;
    in
    pkgs.writeText "eval-herdr-default-off" (
      if !(hasUnit hm "herdr-server") && !(hasSystemPackage eval.config "herdr") then
        "pass"
      else
        throw "FAIL: herdr is active without marchyo.ai.herdr.enable"
    );

  # herdr on with a picked agent: package, server unit, bind, one integration.
  eval-herdr-enabled =
    let
      eval = evalWith {
        marchyo.ai.herdr.enable = true;
        marchyo.development.enable = true;
        marchyo.defaults.aiAgent = "claude-code";
      };
      hm = hmFor eval;
      exec = toString hm.systemd.user.services.herdr-server.Service.ExecStart;
    in
    pkgs.writeText "eval-herdr-enabled" (
      if
        hasSystemPackage eval.config "herdr"
        && lib.hasSuffix "/bin/herdr server" exec
        && hyprHasBind (binds hm) "SUPER + CTRL + return" "herdr"
        && hasUnit hm "herdr-integration-claude"
        && !(hasUnit hm "herdr-integration-codex")
      then
        "pass"
      else
        throw "FAIL: herdr package, server unit, bind or claude integration missing"
    );

  # No agent installed: the server runs but no integration unit exists.
  eval-herdr-no-agent-no-integration =
    let
      hm = hmFor (evalWith {
        marchyo.ai.herdr.enable = true;
      });
    in
    pkgs.writeText "eval-herdr-no-agent-no-integration" (
      if
        hasUnit hm "herdr-server"
        && !(lib.any (n: lib.hasPrefix "herdr-integration-" n) (lib.attrNames hm.systemd.user.services))
      then
        "pass"
      else
        throw "FAIL: herdr integration units exist without an installed agent"
    );

  eval-ai-tools-amp-cli =
    testNixOSCheck "ai-tools-amp-cli" (cfg: hasSystemPackage cfg "amp")
      (withTestUser {
        marchyo.ai.amp.enable = true;
      });

  eval-ai-tools-amp-unfree-assertion =
    testNixOSFails "ai-tools-amp-unfree" "nixpkgs.config.allowUnfree is false"
      (
        lib.recursiveUpdate (withTestUser { marchyo.ai.amp.enable = true; }) {
          nixpkgs.config.allowUnfree = false;
        }
      );

  eval-ai-tools-amp-desktop-unfree-assertion =
    testNixOSFails "ai-tools-amp-desktop-unfree" "amp-desktop"
      (
        lib.recursiveUpdate (withTestUser { marchyo.ai.amp.desktop.enable = true; }) {
          nixpkgs.config.allowUnfree = false;
        }
      );

  eval-ai-tools-herdr-app =
    testNixOSCheck "ai-tools-herdr-app" (cfg: hasSystemPackage cfg "herdr-app")
      (withTestUser {
        marchyo.ai.herdr.desktop.enable = true;
      });

  check-home-hyprland-config-console = mkVerifyConfig "check-hyprland-config-console" {
    marchyo.ai.herdr.enable = true;
  };
}

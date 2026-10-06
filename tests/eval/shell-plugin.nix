# Build-time shell plugin platform (Option A). Eval-only: proves the
# mkMarchyoShellPlugin builder wires its passthru metadata and produces a
# derivation, without forcing the (heavy) plugin/shell build.
{
  helpers,
  lib,
  pkgs,
  ...
}:
let
  inherit (helpers) assertTest testNixOSCheck withTestUser;

  # A representative CLI-added plugin spec (the shape `marchyo plugin add`
  # persists into the marchyoCliState sidecar). Reading it back exercises the
  # marchyo.shell.extraPlugins submodule type without forcing the fetchgit
  # build (that only happens in the Home-Manager shell module, not in these
  # NixOS-only eval configs).
  spec = {
    id = "example.hello";
    url = "https://example.com/example-hello.git";
    rev = "0123456789abcdef0123456789abcdef01234567";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    kinds = [ "bar-widget" ];
    entryPoints = {
      barWidget = "Panel.qml";
    };
  };

  # The test harness passes a bare nixpkgs (no marchyo overlay), so build the
  # plugin straight from plugin.nix via callPackage rather than
  # pkgs.mkMarchyoShellPlugin. callPackage fills the tool args and leaves the
  # { src, id, ... } function.
  mkPlugin = pkgs.callPackage ../../packages/marchyo-shell/plugin.nix { };

  plugin = mkPlugin {
    src = ./fixtures/example-plugin;
    id = "example.hello";
    kinds = [ "bar-widget" ];
    entryPoints = {
      barWidget = "BarWidget.qml";
    };
  };
  m = plugin.marchyoPlugin;

  launcher = mkPlugin {
    src = ./fixtures/example-launcher;
    id = "example.echo";
    name = "Echo";
    version = "1.0.0";
    kinds = [ "launcher" ];
    prefix = "?";
    entryPoints.launcher = "Provider.qml";
  };

  daemon = mkPlugin {
    src = ./fixtures/example-daemon;
    id = "example.ticker";
    name = "Ticker";
    version = "1.0.0";
    kinds = [ "daemon" ];
    entryPoints.daemon = "Daemon.qml";
    source = {
      url = "https://example.com/example-ticker.git";
      rev = "0123456789abcdef0123456789abcdef01234567";
    };
  };

  # True when building the plugin aborts at eval time (an assert). deepSeq on
  # drvPath forces the derivation without building it.
  aborts = args: !(builtins.tryEval (builtins.deepSeq (mkPlugin args).drvPath true)).success;

  # The lock document package.nix serializes (no shell build needed).
  mkLock = import ../../packages/marchyo-shell/plugin-lock.nix { inherit (pkgs) lib; };
  lock = mkLock [
    plugin
    launcher
    daemon
  ];
  # Round-trip through JSON (the file package.nix writes). fromJSON refuses
  # store path context, so drop it first.
  lockJson = builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.toJSON lock));

  # extraPlugins type check, evaluated against the platform-neutral option
  # declarations alone.
  extraPluginsAccept =
    specs:
    (builtins.tryEval (
      builtins.deepSeq
        (pkgs.lib.evalModules {
          modules = [
            ../../modules/nixos/options/shell.nix
            { marchyo.shell.extraPlugins = specs; }
          ];
        }).config.marchyo.shell.extraPlugins
        true
    )).success;
in
{
  eval-shell-plugin-metadata = assertTest "shell-plugin-metadata" (
    m.id == "example.hello"
    && m.kinds == [ "bar-widget" ]
    && m.entryPoints.barWidget == "BarWidget.qml"
    && plugin ? outPath
  ) "mkMarchyoShellPlugin must expose passthru.marchyoPlugin and be a derivation";

  # The marchyo.* namespace is reserved: building such a plugin must abort.
  eval-shell-plugin-reserved-ns = assertTest "shell-plugin-reserved-ns" (
    !(builtins.tryEval (mkPlugin {
      src = ./fixtures/example-plugin;
      id = "marchyo.hello";
      kinds = [ "bar-widget" ];
      entryPoints = {
        barWidget = "BarWidget.qml";
      };
    })).success
  ) "mkMarchyoShellPlugin must refuse the reserved marchyo.* id namespace";

  # The CLI-owned additive option accepts a raw pinned git spec and round-trips
  # its manifest fields (darwin-neutral; no pkgs, no fetch).
  eval-shell-extra-plugins-option =
    testNixOSCheck "shell-extra-plugins-option"
      (
        cfg:
        let
          p = builtins.head cfg.marchyo.shell.extraPlugins;
        in
        builtins.length cfg.marchyo.shell.extraPlugins == 1
        && p.id == "example.hello"
        && p.rev == spec.rev
        && p.kinds == [ "bar-widget" ]
        && p.entryPoints.barWidget == "Panel.qml"
        && p.name == null
        && p.version == null
        && p.prefix == null
      )
      (withTestUser {
        marchyo.shell.extraPlugins = [ spec ];
      });

  # Kinds are a closed set.
  eval-shell-plugin-unknown-kind = assertTest "shell-plugin-unknown-kind" (aborts {
    src = ./fixtures/example-plugin;
    id = "example.hello";
    kinds = [ "panel" ];
    entryPoints.panel = "BarWidget.qml";
  }) "mkMarchyoShellPlugin must refuse a kind outside bar-widget, launcher, daemon";

  # entryPoints carries exactly the keys of the declared kinds.
  eval-shell-plugin-entrypoint-mismatch = assertTest "shell-plugin-entrypoint-mismatch" (
    aborts {
      src = ./fixtures/example-plugin;
      id = "example.hello";
      kinds = [ "bar-widget" ];
      entryPoints = {
        barWidget = "BarWidget.qml";
        daemon = "BarWidget.qml";
      };
    }
    && aborts {
      src = ./fixtures/example-plugin;
      id = "example.hello";
      kinds = [
        "bar-widget"
        "daemon"
      ];
      entryPoints.barWidget = "BarWidget.qml";
    }
  ) "mkMarchyoShellPlugin must refuse entryPoints that do not match the kinds";

  # A launcher plugin needs a prefix, and the prefix stays clear of the
  # first-party launcher prefixes.
  eval-shell-plugin-launcher-prefix = assertTest "shell-plugin-launcher-prefix" (
    let
      base = {
        src = ./fixtures/example-launcher;
        id = "example.echo";
        kinds = [ "launcher" ];
        entryPoints.launcher = "Provider.qml";
      };
    in
    aborts base
    && aborts (base // { prefix = ""; })
    && aborts (base // { prefix = "a b"; })
    && lib.all (p: aborts (base // { prefix = p; })) [
      "="
      ">"
      ">theme"
      "#x"
      "!"
    ]
    # prefix is launcher-only.
    && aborts {
      src = ./fixtures/example-plugin;
      id = "example.hello";
      kinds = [ "bar-widget" ];
      prefix = "?";
      entryPoints.barWidget = "BarWidget.qml";
    }
  ) "mkMarchyoShellPlugin must require a non-reserved prefix for launcher plugins only";

  eval-shell-plugin-launcher-daemon-metadata = assertTest "shell-plugin-launcher-daemon-metadata" (
    launcher.marchyoPlugin.kinds == [ "launcher" ]
    && launcher.marchyoPlugin.prefix == "?"
    && launcher.marchyoPlugin.entryPoints == { launcher = "Provider.qml"; }
    && launcher.marchyoPlugin.source == null
    && launcher ? outPath
    && daemon.marchyoPlugin.kinds == [ "daemon" ]
    && daemon.marchyoPlugin.prefix == null
    && daemon.marchyoPlugin.entryPoints == { daemon = "Daemon.qml"; }
    && daemon.marchyoPlugin.source.rev == "0123456789abcdef0123456789abcdef01234567"
    && daemon ? outPath
  ) "launcher and daemon fixtures must expose their passthru.marchyoPlugin metadata";

  eval-shell-plugin-lock = assertTest "shell-plugin-lock" (
    let
      byId = lib.listToAttrs (map (p: lib.nameValuePair p.id p) lockJson.plugins);
    in
    lockJson.lockVersion == 1
    &&
      map (p: p.id) lockJson.plugins == [
        "example.hello"
        "example.echo"
        "example.ticker"
      ]
    && lib.all (
      p:
      lib.attrNames p == [
        "entryPoints"
        "id"
        "kinds"
        "name"
        "prefix"
        "source"
        "storePath"
        "version"
      ]
    ) lockJson.plugins
    && byId."example.hello".prefix == null
    && byId."example.hello".source == null
    && byId."example.hello".storePath == plugin.outPath
    && byId."example.echo".prefix == "?"
    && byId."example.echo".kinds == [ "launcher" ]
    && byId."example.echo".entryPoints == { launcher = "Provider.qml"; }
    &&
      byId."example.ticker".source == {
        url = "https://example.com/example-ticker.git";
        rev = "0123456789abcdef0123456789abcdef01234567";
      }
    && byId."example.ticker".version == "1.0.0"
    &&
      (mkLock [ ]) == {
        lockVersion = 1;
        plugins = [ ];
      }
  ) "plugin-lock.nix must produce the lockVersion 1 document";

  # Ids and launcher prefixes are unique across the shell.
  eval-shell-plugin-lock-duplicates = assertTest "shell-plugin-lock-duplicates" (
    !(builtins.tryEval (
      builtins.deepSeq (mkLock [
        plugin
        plugin
      ]) true
    )).success
    && !(builtins.tryEval (
      builtins.deepSeq (mkLock [
        launcher
        (mkPlugin {
          src = ./fixtures/example-launcher;
          id = "example.echo2";
          kinds = [ "launcher" ];
          prefix = "?";
          entryPoints.launcher = "Provider.qml";
        })
      ]) true
    )).success
  ) "plugin-lock.nix must refuse duplicate plugin ids and launcher prefixes";

  # The extraPlugins kinds enum rejects an unknown kind and accepts the set.
  eval-shell-extra-plugins-kind-enum = assertTest "shell-extra-plugins-kind-enum" (
    extraPluginsAccept [ spec ]
    && extraPluginsAccept [
      (
        spec
        // {
          kinds = [ "launcher" ];
          entryPoints.launcher = "Provider.qml";
          prefix = "?";
        }
      )
    ]
    && !extraPluginsAccept [ (spec // { kinds = [ "service" ]; }) ]
  ) "marchyo.shell.extraPlugins kinds must be the closed bar-widget/launcher/daemon enum";
}

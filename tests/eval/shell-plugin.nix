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
  inherit (helpers)
    assertTest
    testNixOSCheck
    testNixOSFails
    withTestUser
    ;

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

  replacer = mkPlugin {
    src = ./fixtures/example-replacer;
    id = "example.audio";
    name = "Example audio";
    version = "1.0.0";
    kinds = [ "panel" ];
    entryPoints.panel = "Panel.qml";
    replaces = [
      "panel.audio"
      "polkit"
    ];
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

  extraClaim =
    id: role:
    spec
    // {
      inherit id;
      replaces = [ role ];
    };

  lockJsonReplacer = builtins.fromJSON (
    builtins.unsafeDiscardStringContext (builtins.toJSON (mkLock [ replacer ]))
  );

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

  # Ids are path components of the dev dir and shell words in the build script,
  # so traversal and metacharacters must abort for the primary and sibling ids.
  eval-shell-plugin-id-shape = assertTest "shell-plugin-id-shape" (
    let
      args = id: {
        src = ./fixtures/example-plugin;
        inherit id;
        kinds = [ "bar-widget" ];
        entryPoints.barWidget = "BarWidget.qml";
      };
    in
    aborts (args "../../x")
    && aborts (args "a/b")
    && aborts (args "a..b")
    && aborts (args "x$(touch pwned)")
    && aborts (
      args "acme.ok"
      // {
        siblings = [
          {
            manifest = "other.manifest.json";
            id = "x$(touch pwned)";
            kinds = [ "bar-widget" ];
            entryPoints.barWidget = "BarWidget.qml";
          }
        ];
      }
    )
  ) "plugin ids must be [A-Za-z0-9][A-Za-z0-9._-]* without '..'";

  # The omarchy namespace is reserved too, unless the vendored-omarchy flag
  # lifts it; the marchyo one never is.
  eval-shell-plugin-omarchy-ns = assertTest "shell-plugin-omarchy-ns" (
    let
      args = id: {
        src = ./fixtures/example-plugin;
        inherit id;
        kinds = [ "bar-widget" ];
        entryPoints.barWidget = "BarWidget.qml";
      };
    in
    aborts (args "omarchy.hello")
    && !(aborts (args "omarchy.hello" // { omarchyFirstParty = true; }))
    && aborts (args "marchyo.hello" // { omarchyFirstParty = true; })
  ) "omarchy.* ids need omarchyFirstParty and marchyo.* ids are never allowed";

  # The omarchy kinds, keepLoaded, the barWidget block and sibling manifests.
  eval-shell-plugin-omarchy-kinds = assertTest "shell-plugin-omarchy-kinds" (
    let
      mk =
        extra:
        mkPlugin (
          {
            src = ./fixtures/example-panel;
            id = "example.panel";
            name = "Example panel";
            version = "1.0.0";
            kinds = [
              "panel"
              "menu"
            ];
            keepLoaded = true;
            entryPoints = {
              panel = "Panel.qml";
              menu = "Menu.qml";
            };
            siblings = [ sibling ];
          }
          // extra
        );
      sibling = {
        manifest = "widgets/Spacer.manifest.json";
        id = "example.spacer";
        name = "Spacer";
        version = "1.0.0";
        kinds = [ "bar-widget" ];
        entryPoints.barWidget = "Spacer.qml";
        barWidget = {
          displayName = "Spacer";
          allowMultiple = true;
          defaultSection = "left";
        };
      };
      p = mk { };
      m = p.marchyoPlugin;
      lock' = builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.toJSON (mkLock [ p ])));
      spacer = lib.findFirst (e: e.id == "example.spacer") null lock'.plugins;
      broken = extra: !(builtins.tryEval (builtins.deepSeq (mk extra).drvPath true)).success;
    in
    m.keepLoaded
    && m.siblings != [ ]
    && (builtins.head m.siblings).entryPoints.barWidget == "widgets/Spacer.qml"
    && spacer.parent == "example.panel"
    && spacer.barWidget.defaultSection == "left"
    &&
      map (e: e.id) lock'.plugins == [
        "example.panel"
        "example.spacer"
      ]
    # The set of ids and the barWidget block are checked at eval time.
    && broken { siblings = [ (sibling // { id = "example.panel"; }) ]; }
    && broken {
      siblings = [
        (
          sibling
          // {
            barWidget = {
              defaultSection = "nowhere";
            };
          }
        )
      ];
    }
  ) "plugin.nix must accept the omarchy kinds, keepLoaded and siblings, and check them";

  # The CLI-owned additive option accepts a raw pinned git spec and round-trips
  # its manifest fields (no pkgs, no fetch).
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

  # The dev loader is off by default and barPlugin is unset.
  eval-shell-dev-plugins-default = testNixOSCheck "shell-dev-plugins-default" (
    cfg: !cfg.marchyo.shell.devPlugins.enable && cfg.marchyo.shell.barPlugin == null
  ) (withTestUser { });

  eval-shell-dev-plugins-option =
    testNixOSCheck "shell-dev-plugins-option"
      (cfg: cfg.marchyo.shell.devPlugins.enable && cfg.marchyo.shell.barPlugin == "acme.bar")
      (withTestUser {
        marchyo.shell.devPlugins.enable = true;
        marchyo.shell.barPlugin = "acme.bar";
      });

  # Kinds are a closed set.
  eval-shell-plugin-unknown-kind = assertTest "shell-plugin-unknown-kind" (aborts {
    src = ./fixtures/example-plugin;
    id = "example.hello";
    kinds = [ "widget" ];
    entryPoints.widget = "BarWidget.qml";
  }) "mkMarchyoShellPlugin must refuse a kind outside the closed kind set";

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
        "barWidget"
        "entryPoints"
        "id"
        "keepLoaded"
        "kinds"
        "name"
        "parent"
        "prefix"
        "replaces"
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
    && !extraPluginsAccept [ (spec // { kinds = [ "bogus" ]; }) ]
  ) "marchyo.shell.extraPlugins kinds must be the closed plugin kind enum";

  eval-shell-plugin-replaces = assertTest "shell-plugin-replaces" (
    replacer.marchyoPlugin.replaces == [
      "panel.audio"
      "polkit"
    ]
    && m.replaces == [ ]
    && replacer ? outPath
    && (lib.findFirst (e: e.id == "example.audio") null lockJsonReplacer.plugins).replaces == [
      "panel.audio"
      "polkit"
    ]
    && (lib.findFirst (e: e.id == "example.hello") null lockJson.plugins).replaces == [ ]
  ) "replaces must reach passthru and plugins.lock.json, defaulting to []";

  eval-shell-plugin-replaces-bad-role = assertTest "shell-plugin-replaces-bad-role" (
    aborts {
      src = ./fixtures/example-replacer;
      id = "example.audio";
      kinds = [ "panel" ];
      entryPoints.panel = "Panel.qml";
      replaces = [ "panel.bogus" ];
    }
    && aborts {
      src = ./fixtures/example-plugin;
      id = "example.hello";
      kinds = [ "bar-widget" ];
      entryPoints.barWidget = "BarWidget.qml";
      siblings = [
        {
          manifest = "other.manifest.json";
          id = "example.other";
          kinds = [ "bar-widget" ];
          entryPoints.barWidget = "Other.qml";
          replaces = [ "nope" ];
        }
      ];
    }
  ) "mkMarchyoShellPlugin must refuse a replaces role outside native-roles.nix";

  eval-shell-plugin-lock-duplicate-role = assertTest "shell-plugin-lock-duplicate-role" (
    !(builtins.tryEval (
      builtins.deepSeq (mkLock [
        replacer
        (mkPlugin {
          src = ./fixtures/example-plugin;
          id = "example.other";
          kinds = [ "bar-widget" ];
          entryPoints.barWidget = "BarWidget.qml";
          replaces = [ "polkit" ];
        })
      ]) true
    )).success
  ) "plugin-lock.nix must refuse a native role replaced by two plugins";

  eval-shell-replaced-roles-empty = testNixOSCheck "shell-replaced-roles-empty" (
    c: c.marchyo.shell.replacedRoles == { }
  ) (withTestUser { });

  eval-shell-replaced-roles = testNixOSCheck "shell-replaced-roles" (
    c:
    c.marchyo.shell.replacedRoles == {
      "panel.audio" = "example.audio";
      polkit = "example.audio";
      "panel.power" = "example.power";
    }
  ) (withTestUser {
    marchyo.shell = {
      plugins = [ replacer ];
      extraPlugins = [ (extraClaim "example.power" "panel.power") ];
    };
  });

  eval-shell-replaced-roles-duplicate =
    testNixOSFails "shell-replaced-roles-duplicate"
      "native role 'panel.audio' is replaced by more than one plugin: example.audio, example.other"
      (withTestUser {
        marchyo.shell = {
          plugins = [ replacer ];
          extraPlugins = [ (extraClaim "example.other" "panel.audio") ];
        };
      });
}

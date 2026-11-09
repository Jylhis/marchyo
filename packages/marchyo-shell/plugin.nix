# Build-time validator + normalizer for a Marchyo shell plugin (the Option A
# model: plugins are Nix-declared and baked into the store shell, never
# discovered at runtime; the opt-in dev loader in `marchyo plugin dev` is the
# one exception, see shell/Commons/PluginIndex.qml).
#
# The manifest.json at the root of `src` is the source of truth and is validated
# here at build time (schema version, matching id, kinds, entry points and
# launcher prefix equal to the declared args, reserved namespace, safe entry
# points, no symlinks). The id/kinds/entryPoints/prefix args mirror the manifest
# at eval time, kept IFD-free on purpose, and are carried on
# passthru.marchyoPlugin so packages/marchyo-shell/package.nix can generate
# Commons/PluginIndex.qml and plugins.lock.json without reading files.
#
# Kinds are the closed set in ./plugin-kinds.nix; entryPoints carries exactly
# one key per declared kind. A launcher plugin declares the query `prefix` that
# routes the apps palette to it.
#
# Omarchy manifest fields: `keepLoaded` mounts a panel, menu or overlay at
# startup, `barWidget` is the bar-widget metadata block (checked for shape, and
# compared with the manifest when given), `replaces` names native roles the
# plugin takes over (a manifest without the key defers to the declaration, so
# vendored upstream manifests stay verbatim), and `siblings` lists the extra
# `*.manifest.json` files of a plugin directory, each its own plugin id whose
# entry points are relative to its manifest's directory. The `omarchy.*` and
# `marchyo.*` id namespaces are reserved; `omarchyFirstParty` lifts the omarchy
# one for the vendored omarchy plugins in overlay.nix.
{
  lib,
  stdenvNoCC,
  jq,
  findutils,
}:
{
  src,
  id,
  kinds,
  entryPoints,
  name ? id,
  version ? "0",
  # Launcher query prefix; required for the "launcher" kind, null otherwise.
  prefix ? null,
  # Pinned origin { url, rev } recorded in plugins.lock.json; null when the pin
  # lives elsewhere (a flake input or an in-tree fetchgit).
  source ? null,
  keepLoaded ? false,
  # Native roles (./native-roles.nix) this plugin takes over from the shell.
  replaces ? [ ],
  # The manifest's `barWidget` block; null leaves it unchecked and unrecorded.
  barWidget ? null,
  # [ { manifest, id, kinds, entryPoints, name?, version?, prefix?, keepLoaded?, replaces?, barWidget? } ]
  siblings ? [ ],
  omarchyFirstParty ? false,
}:
let
  pluginKinds = import ./plugin-kinds.nix;
  nativeRoles = import ./native-roles.nix;
  # Leading characters of the first-party launcher prefixes in
  # shell/Commons/LauncherProviders.js PREFIXES (contract-tested).
  reservedPrefixStarts = [
    "="
    ">"
    "#"
    "!"
  ];
  reservedNamespaces = [ "marchyo." ] ++ lib.optional (!omarchyFirstParty) "omarchy.";
  barSections = [
    "left"
    "centerBegin"
    "center"
    "centerEnd"
    "tray"
    "right"
  ];
  barWidgetKeys = [
    "displayName"
    "description"
    "category"
    "allowMultiple"
    "aliases"
    "defaultSection"
    "defaults"
    "schema"
    "settingsForm"
  ];

  barWidgetOk =
    b:
    b == null
    || (
      builtins.isAttrs b
      && lib.all (k: lib.elem k barWidgetKeys) (lib.attrNames b)
      && builtins.isBool (b.allowMultiple or false)
      && lib.elem (b.defaultSection or "centerEnd") barSections
      && builtins.isAttrs (b.defaults or { })
      && builtins.isList (b.schema or [ ])
    );

  dirOfManifest =
    m:
    let
      d = builtins.dirOf m;
    in
    if d == "." then "" else "${d}/";

  # Every entry (primary or sibling) validated the same way.
  check =
    e:
    let
      eKinds = e.kinds;
      ePrefix = e.prefix or null;
      unknownRoles = lib.filter (r: !(lib.elem r nativeRoles)) (e.replaces or [ ]);
      unknownKinds = lib.filter (k: !(pluginKinds ? ${k})) eKinds;
      expectedKeys = lib.sort lib.lessThan (lib.unique (map (k: pluginKinds.${k}) eKinds));
      isLauncher = lib.elem "launcher" eKinds;
      prefixOk =
        ePrefix != null
        && ePrefix != ""
        && builtins.match ".*[[:space:]].*" ePrefix == null
        && !(lib.any (s: lib.hasPrefix s ePrefix) reservedPrefixStarts);
    in
    assert lib.assertMsg (
      builtins.match "[A-Za-z0-9][A-Za-z0-9._-]*" e.id != null && !(lib.hasInfix ".." e.id)
    ) "marchyo shell plugin id '${e.id}': ids must match [A-Za-z0-9][A-Za-z0-9._-]* and not contain '..'";
    assert lib.assertMsg (lib.all (ns: !lib.hasPrefix ns e.id) reservedNamespaces)
      "marchyo shell plugin id '${e.id}': the ${lib.concatStringsSep ", " reservedNamespaces} namespace(s) are reserved for first-party surfaces";
    assert lib.assertMsg (
      eKinds != [ ]
    ) "marchyo shell plugin '${e.id}': at least one kind is required";
    assert lib.assertMsg (unknownKinds == [ ])
      "marchyo shell plugin '${e.id}': unknown kind(s) ${lib.concatStringsSep ", " unknownKinds}; valid kinds are ${lib.concatStringsSep ", " (lib.attrNames pluginKinds)}";
    assert lib.assertMsg (lib.attrNames e.entryPoints == expectedKeys)
      "marchyo shell plugin '${e.id}': entryPoints keys (${lib.concatStringsSep ", " (lib.attrNames e.entryPoints)}) must be exactly ${lib.concatStringsSep ", " expectedKeys} for kinds ${lib.concatStringsSep ", " eKinds}";
    assert lib.assertMsg (
      isLauncher || ePrefix == null
    ) "marchyo shell plugin '${e.id}': prefix only applies to the launcher kind";
    assert lib.assertMsg (!isLauncher || prefixOk)
      "marchyo shell plugin '${e.id}': a launcher plugin needs a non-empty prefix without whitespace that does not start with ${lib.concatStringsSep " " reservedPrefixStarts} (first-party launcher prefixes)";
    assert lib.assertMsg (unknownRoles == [ ])
      "marchyo shell plugin '${e.id}': unknown replaces role(s) ${lib.concatStringsSep ", " unknownRoles}; valid roles are ${lib.concatStringsSep ", " nativeRoles}";
    assert lib.assertMsg (barWidgetOk (e.barWidget or null))
      "marchyo shell plugin '${e.id}': barWidget must be an attrset of ${lib.concatStringsSep ", " barWidgetKeys} with a defaultSection from ${lib.concatStringsSep ", " barSections}";
    assert lib.assertMsg (
      (e.barWidget or null) == null || lib.elem "bar-widget" eKinds
    ) "marchyo shell plugin '${e.id}': barWidget only applies to the bar-widget kind";
    true;

  primary = {
    inherit
      id
      kinds
      entryPoints
      prefix
      replaces
      barWidget
      ;
  };

  # Sibling entries as the index consumes them: entry points relative to the
  # plugin root.
  normalizedSiblings = map (s: {
    inherit (s) id kinds manifest;
    name = s.name or s.id;
    version = s.version or version;
    prefix = s.prefix or null;
    keepLoaded = s.keepLoaded or false;
    replaces = s.replaces or [ ];
    barWidget = s.barWidget or null;
    entryPoints = lib.mapAttrs (_: ep: "${dirOfManifest s.manifest}${ep}") s.entryPoints;
    # Entry points as written in the sibling's manifest, for the build check.
    manifestEntryPoints = s.entryPoints;
  }) siblings;

  siblingIds = map (s: s.id) siblings;
  allIds = [ id ] ++ siblingIds;
  dupIds = lib.unique (lib.filter (x: lib.count (y: y == x) allIds > 1) allIds);

  siblingCheck = lib.concatMapStringsSep "\n" (s: ''
    sm=${lib.escapeShellArg s.manifest}
    test -f "$sm" || {
      echo "plugin ${id}: sibling manifest '$sm' does not exist" >&2
      exit 1
    }
    case "$sm" in
      /* | *..*)
        echo "plugin ${id}: unsafe sibling manifest path '$sm'" >&2
        exit 1
        ;;
    esac
    [ "$(jq -r '.id // ""' "$sm")" = ${lib.escapeShellArg s.id} ] || {
      echo "plugin ${id}: sibling '$sm' id does not match '"${lib.escapeShellArg s.id}" >&2
      exit 1
    }
    jq -e --argjson k ${lib.escapeShellArg (builtins.toJSON s.kinds)} \
      '((.kinds // []) | sort) == ($k | sort)' "$sm" >/dev/null || {
      echo "plugin ${id}: sibling '$sm' kinds do not match the declared kinds" >&2
      exit 1
    }
    jq -e --argjson r ${lib.escapeShellArg (builtins.toJSON s.replaces)} \
      '.replaces == null or .replaces == $r' "$sm" >/dev/null || {
      echo "plugin ${id}: sibling '$sm' replaces do not match the declared replaces" >&2
      exit 1
    }
    jq -e --argjson e ${lib.escapeShellArg (builtins.toJSON s.manifestEntryPoints)} \
      '(.entryPoints // {}) == $e' "$sm" >/dev/null || {
      echo "plugin ${id}: sibling '$sm' entryPoints do not match the declared entryPoints" >&2
      exit 1
    }
    for ep in ${lib.escapeShellArgs (lib.attrValues s.entryPoints)}; do
      case "$ep" in
        /* | *..*)
          echo "plugin ${id}: unsafe entry point path '$ep'" >&2
          exit 1
          ;;
      esac
      test -f "$ep" || {
        echo "plugin ${id}: sibling entry point '$ep' does not exist" >&2
        exit 1
      }
    done
  '') normalizedSiblings;
in
assert check primary;
assert lib.assertMsg (lib.all (
  s: check (s // { entryPoints = s.manifestEntryPoints; })
) normalizedSiblings) "marchyo shell plugin '${id}': invalid sibling";
assert lib.assertMsg (dupIds == [ ])
  "marchyo shell plugin '${id}': duplicate id(s) ${lib.concatStringsSep ", " dupIds} among the manifest and its siblings";
stdenvNoCC.mkDerivation {
  pname = "marchyo-shell-plugin-${lib.replaceStrings [ "." ] [ "-" ] id}";
  inherit version src;

  nativeBuildInputs = [
    jq
    findutils
  ];
  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    test -f manifest.json || {
      echo "plugin ${id}: manifest.json missing at the src root" >&2
      exit 1
    }

    mid=$(jq -r '.id // ""' manifest.json)
    [ "$mid" = "${id}" ] || {
      echo "plugin ${id}: manifest id '$mid' does not match the declared id" >&2
      exit 1
    }

    sv=$(jq -r '.schemaVersion // ""' manifest.json)
    [ "$sv" = "1" ] || {
      echo "plugin ${id}: schemaVersion must be 1 (got '$sv')" >&2
      exit 1
    }

    # The manifest's kinds, entry points and prefix must equal the declared args.
    jq -e --argjson k ${lib.escapeShellArg (builtins.toJSON kinds)} \
      '((.kinds // []) | sort) == ($k | sort)' manifest.json >/dev/null || {
      echo "plugin ${id}: manifest kinds $(jq -c '.kinds' manifest.json) do not match the declared kinds" >&2
      exit 1
    }
    jq -e --argjson e ${lib.escapeShellArg (builtins.toJSON entryPoints)} \
      '(.entryPoints // {}) == $e' manifest.json >/dev/null || {
      echo "plugin ${id}: manifest entryPoints $(jq -c '.entryPoints' manifest.json) do not match the declared entryPoints" >&2
      exit 1
    }
    jq -e --argjson p ${lib.escapeShellArg (builtins.toJSON prefix)} \
      '(.prefix // null) == $p' manifest.json >/dev/null || {
      echo "plugin ${id}: manifest prefix $(jq -c '.prefix' manifest.json) does not match the declared prefix" >&2
      exit 1
    }
    jq -e --argjson k ${lib.boolToString keepLoaded} \
      '(.keepLoaded // false) == $k' manifest.json >/dev/null || {
      echo "plugin ${id}: manifest keepLoaded does not match the declared keepLoaded" >&2
      exit 1
    }
    jq -e --argjson r ${lib.escapeShellArg (builtins.toJSON replaces)} \
      '.replaces == null or .replaces == $r' manifest.json >/dev/null || {
      echo "plugin ${id}: manifest replaces does not match the declared replaces" >&2
      exit 1
    }
    ${lib.optionalString (barWidget != null) ''
      jq -e --argjson b ${lib.escapeShellArg (builtins.toJSON barWidget)} \
        '(.barWidget // null) == $b' manifest.json >/dev/null || {
        echo "plugin ${id}: manifest barWidget does not match the declared barWidget" >&2
        exit 1
      }
    ''}

    # No symlinks anywhere inside the plugin (they could point out of the tree).
    if [ -n "$(find . -type l)" ]; then
      echo "plugin ${id}: symlinks are not allowed inside a plugin" >&2
      exit 1
    fi

    # Every declared entry point must be a safe relative path that exists.
    for ep in ${lib.escapeShellArgs (lib.attrValues entryPoints)}; do
      case "$ep" in
        /* | *..*)
          echo "plugin ${id}: unsafe entry point path '$ep'" >&2
          exit 1
          ;;
      esac
      test -f "$ep" || {
        echo "plugin ${id}: entry point '$ep' does not exist" >&2
        exit 1
      }
    done

    ${siblingCheck}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r . "$out/"
    runHook postInstall
  '';

  passthru.marchyoPlugin = {
    inherit
      id
      name
      version
      kinds
      entryPoints
      prefix
      source
      keepLoaded
      replaces
      barWidget
      ;
    siblings = map (s: removeAttrs s [ "manifestEntryPoints" ]) normalizedSiblings;
  };
}

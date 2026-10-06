# Build-time validator + normalizer for a Marchyo shell plugin (the Option A
# model: plugins are Nix-declared and baked into the store shell, never
# discovered at runtime).
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
}:
let
  pluginKinds = import ./plugin-kinds.nix;
  # Leading characters of the first-party launcher prefixes in
  # shell/Commons/LauncherProviders.js PREFIXES (contract-tested).
  reservedPrefixStarts = [
    "="
    ">"
    "#"
    "!"
  ];
  unknownKinds = lib.filter (k: !(pluginKinds ? ${k})) kinds;
  expectedKeys = lib.sort lib.lessThan (lib.unique (map (k: pluginKinds.${k}) kinds));
  isLauncher = lib.elem "launcher" kinds;
  prefixOk =
    prefix != null
    && prefix != ""
    && builtins.match ".*[[:space:]].*" prefix == null
    && !(lib.any (s: lib.hasPrefix s prefix) reservedPrefixStarts);
in
assert lib.assertMsg (
  !lib.hasPrefix "marchyo." id
) "marchyo shell plugin id '${id}': the marchyo.* namespace is reserved for first-party surfaces";
assert lib.assertMsg (kinds != [ ]) "marchyo shell plugin '${id}': at least one kind is required";
assert lib.assertMsg (unknownKinds == [ ])
  "marchyo shell plugin '${id}': unknown kind(s) ${lib.concatStringsSep ", " unknownKinds}; valid kinds are ${lib.concatStringsSep ", " (lib.attrNames pluginKinds)}";
assert lib.assertMsg (lib.attrNames entryPoints == expectedKeys)
  "marchyo shell plugin '${id}': entryPoints keys (${lib.concatStringsSep ", " (lib.attrNames entryPoints)}) must be exactly ${lib.concatStringsSep ", " expectedKeys} for kinds ${lib.concatStringsSep ", " kinds}";
assert lib.assertMsg (
  isLauncher || prefix == null
) "marchyo shell plugin '${id}': prefix only applies to the launcher kind";
assert lib.assertMsg (!isLauncher || prefixOk)
  "marchyo shell plugin '${id}': a launcher plugin needs a non-empty prefix without whitespace that does not start with ${lib.concatStringsSep " " reservedPrefixStarts} (first-party launcher prefixes)";
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
      ;
  };
}

# Build-time validator + normalizer for a Marchyo shell plugin (the Option A
# model: plugins are Nix-declared and baked into the store shell, never
# discovered at runtime).
#
# The manifest.json at the root of `src` is the source of truth and is validated
# here at build time (schema version, matching id, reserved namespace, safe
# entry points, no symlinks). The id/kinds/entryPoints args mirror the manifest
# at eval time — kept IFD-free on purpose — and are carried on
# passthru.marchyoPlugin so packages/marchyo-shell/package.nix can regenerate
# Commons/PluginIndex.qml without reading files.
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
}:
assert lib.assertMsg (
  !lib.hasPrefix "marchyo." id
) "marchyo shell plugin id '${id}': the marchyo.* namespace is reserved for first-party surfaces";
assert lib.assertMsg (kinds != [ ]) "marchyo shell plugin '${id}': at least one kind is required";
assert lib.assertMsg (
  entryPoints != { }
) "marchyo shell plugin '${id}': entryPoints must map each kind to a QML file";
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
      ;
  };
}

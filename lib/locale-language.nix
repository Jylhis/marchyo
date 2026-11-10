# The registry code (shell/i18n/locales.json shape) for a system locale such
# as "pt_BR.UTF-8": an exact locale match first (so "pt_BR" picks "pt-BR"),
# then the bare language, else English. Takes the registry as an argument so
# tests can exercise it with synthetic catalogs.
{ lib }:
registry: locale:
let
  codes = builtins.attrNames registry;

  # "fi_FI.UTF-8" -> "fi_FI"
  withoutEncoding = l: builtins.head (lib.splitString "." l);

  full = withoutEncoding locale;
  exact = builtins.filter (code: withoutEncoding registry.${code}.locale == full) codes;
  bare = builtins.head (lib.splitString "_" full);
in
if exact != [ ] then
  builtins.head exact
else if registry ? ${bare} then
  bare
else
  "en"

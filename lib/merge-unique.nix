# Merge attrsets without silent shadowing.
#
# `a // b` quietly drops a's value when both define a name, so two test files
# (or two check sets in outputs.nix) that pick the same name lose one of them
# without a trace. mergeUnique throws instead, naming the duplicate and both
# sources.
#
# Usage:
#   mergeUnique "checks" [
#     { source = "tests/eval/foo.nix"; attrs = { a = ...; }; }
#     { source = "outputs.nix";        attrs = { b = ...; }; }
#   ]
#
# Only the attribute names are forced, never the values, so merging stays as
# lazy as `//`.
{ lib }:
what: sources:
let
  step =
    acc:
    { source, attrs, ... }:
    let
      dupes = builtins.filter (n: acc.attrs ? ${n}) (builtins.attrNames attrs);
    in
    if dupes != [ ] then
      throw "duplicate ${what} name(s): ${
        lib.concatMapStringsSep ", " (n: "'${n}' (in ${source} and ${acc.origin.${n}})") dupes
      }"
    else
      {
        attrs = acc.attrs // attrs;
        origin = acc.origin // lib.mapAttrs (_: _: source) attrs;
      };
in
(lib.foldl' step {
  attrs = { };
  origin = { };
} sources).attrs

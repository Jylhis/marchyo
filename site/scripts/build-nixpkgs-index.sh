#!/usr/bin/env bash
# Build the nixpkgs package search index as a single SQL file for Cloudflare D1.
#
# Enumerates every package in marchyo's *pinned* nixpkgs (the `nixpkgs` flake
# input, i.e. the same rev in flake.lock that consumers get) via `nix-env -qa`
# with `--meta`, and emits schema + INSERTs + FTS rebuild to nixpkgs.sql.
#
# The output is loaded into D1 by .github/workflows/nixpkgs-index.yml with
#   wrangler d1 execute marchyo-nixpkgs --remote --file nixpkgs.sql
#
# Requires: nix (with flakes), jq. Run from the repo root or anywhere inside it.
#
# Usage:
#   site/scripts/build-nixpkgs-index.sh [SYSTEM] [OUT]
#     SYSTEM  nixpkgs system to enumerate (default: x86_64-linux)
#     OUT     output SQL path            (default: site/scripts/nixpkgs.sql)
set -euo pipefail

SYSTEM="${1:-x86_64-linux}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${2:-$SCRIPT_DIR/nixpkgs.sql}"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "resolving pinned nixpkgs for $SYSTEM ..." >&2
# pkgs.path is the nixpkgs source tree for marchyo's pinned rev.
NIXPKGS="$(nix eval --raw "$REPO_ROOT#legacyPackages.${SYSTEM}.path")"
echo "nixpkgs source: $NIXPKGS" >&2

RAW="$(mktemp)"
trap 'rm -f "$RAW"' EXIT

echo "enumerating packages (nix-env -qa --meta) ... this is slow" >&2
# List every available package with metadata. Unfree packages are included in
# the listing (allowUnfree only gates builds, not the query).
NIXPKGS_ALLOW_UNFREE=1 NIXPKGS_ALLOW_INSECURE=1 \
  nix-env -f "$NIXPKGS" -qaP --json --meta --arg config '{ allowAliases = false; }' \
  > "$RAW" 2>/dev/null || \
  NIXPKGS_ALLOW_UNFREE=1 nix-env -f "$NIXPKGS" -qaP --json --meta > "$RAW"

COUNT="$(jq 'length' "$RAW")"
echo "collected $COUNT packages; writing SQL to $OUT" >&2

{
  cat "$SCRIPT_DIR/nixpkgs-schema.sql"
  echo
  echo "BEGIN TRANSACTION;"
  jq -r '
    def esc: gsub("'\''";"'\'\''");
    def lic:
      if . == null then ""
      elif type=="array" then ([.[] | (.spdxId // .shortName // (if type=="string" then . else "" end))] | map(select(. != "")) | join(", "))
      elif type=="object" then (.spdxId // .shortName // "")
      elif type=="string" then .
      else "" end;
    to_entries[]
    | .key as $attr
    | .value as $v
    | ($v.pname // $v.name // $attr) as $pname
    | ($v.version // "") as $ver
    | ((($v.meta.description) // "") | tostring) as $desc
    | (($v.meta.homepage) as $h | if $h==null then "" elif ($h|type)=="array" then ($h[0] // "") else ($h|tostring) end) as $home
    | (($v.meta.license) | lic) as $license
    | (($v.meta.mainProgram) // "") as $main
    | (if ($v.meta.unfree // false) then 1 else 0 end) as $unfree
    | "INSERT INTO packages VALUES ('"
      + ($attr|esc) + "','" + ($pname|esc) + "','" + ($ver|esc) + "','"
      + ($desc|esc) + "','" + ($home|esc) + "','" + ($license|esc) + "','"
      + ($main|esc) + "'," + ($unfree|tostring) + ");"
  ' "$RAW"
  echo "COMMIT;"
  echo
  echo "INSERT INTO packages_fts(packages_fts) VALUES('rebuild');"
} > "$OUT"

echo "done: $OUT ($(wc -l < "$OUT") lines, $COUNT packages)" >&2

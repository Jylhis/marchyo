# Software Bill of Materials (SBOM) generator for a Marchyo system closure.
#
# sbomnix walks the runtime closure of a Nix store path and emits a CycloneDX +
# SPDX + CSV SBOM. It queries the host Nix store (nix / nix-store), so it must
# run impurely on the host — it is exposed as the `sbom` app, not a hermetic
# derivation.
#
#   nix run .#sbom                 # SBOM of the reference x86_64 system
#   nix run .#sbom -- /nix/store/…  # SBOM of an arbitrary store path
#
# Output goes to ./sbom/ (override with $SBOM_OUT). Feed the CycloneDX file into
# `vuln-scan` (vulnxscan) for the vulnerability correlation step.
{
  pkgs,
  defaultTarget,
}:
pkgs.writeShellApplication {
  name = "marchyo-sbom";
  runtimeInputs = [
    pkgs.sbomnix
    pkgs.nix
    pkgs.coreutils
  ];
  text = ''
    target="''${1:-${defaultTarget}}"
    outdir="''${SBOM_OUT:-./sbom}"
    mkdir -p "$outdir"

    echo "==> Generating runtime SBOM for: $target"
    # Runtime closure is sbomnix's default (pass --buildtime for the build
    # closure instead). Offline: it only reads the local Nix store.
    sbomnix "$target" \
      --cdx "$outdir/marchyo.cdx.json" \
      --spdx "$outdir/marchyo.spdx.json" \
      --csv "$outdir/marchyo.csv"

    echo "SBOM written to $outdir/ (CycloneDX marchyo.cdx.json, SPDX marchyo.spdx.json, CSV marchyo.csv)"
  '';
}

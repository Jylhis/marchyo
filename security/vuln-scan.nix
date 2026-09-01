# Vulnerability scan of a Marchyo system closure.
#
# Runs the store-closure CVE scanners on the host against the real system
# closure. Impure by nature: they query the host Nix store AND fetch
# vulnerability data online (NVD / OSV / grype DB), so this is exposed as the
# `vuln-scan` app rather than a hermetic derivation.
#
#   - vulnxscan (from sbomnix) builds an SBOM and correlates it against grype,
#     osv-scanner and vulnix, producing a single de-duplicated CSV.
#   - vulnix scans the closure against NVD directly (the Nix-native scanner).
#
#   nix run .#vuln-scan                 # scan the reference x86_64 system
#   nix run .#vuln-scan -- /nix/store/…  # scan an arbitrary store path
#
# Output goes to ./vuln-scan/ (override with $VULN_OUT). Requires network access
# to fetch the vulnerability databases.
{
  pkgs,
  defaultTarget,
}:
pkgs.writeShellApplication {
  name = "marchyo-vuln-scan";
  runtimeInputs = [
    pkgs.sbomnix # provides vulnxscan
    pkgs.vulnix
    pkgs.grype
    pkgs.osv-scanner
    pkgs.nix
    pkgs.coreutils
  ];
  text = ''
    target="''${1:-${defaultTarget}}"
    outdir="''${VULN_OUT:-./vuln-scan}"
    mkdir -p "$outdir"

    echo "==> vulnxscan (grype + osv-scanner + vulnix) on: $target"
    # vulnxscan aggregates the three scanners and de-duplicates their findings.
    # Don't abort the whole run if one scanner reports a non-zero exit on finds.
    vulnxscan "$target" --out "$outdir/vulnxscan.csv" || true

    echo "==> vulnix (Nix-native NVD scan) on: $target"
    vulnix "$target" > "$outdir/vulnix.txt" 2>&1 || true

    echo "Reports written to $outdir/ (vulnxscan.csv, vulnix.txt)"
    echo "Note: results depend on freshly fetched NVD/OSV/grype data — network required."
  '';
}

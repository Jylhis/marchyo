# Security scanning

Local-only tooling that boots a Marchyo system, audits its hardening, and scans
its package closure for known vulnerabilities. These are **not** wired into the
PR gate (`nix flake check`): the VM test needs KVM and the CVE scanners need
network access to fetch vulnerability databases, so they are run on demand.

## Targets

| Command | What it does |
|---------|--------------|
| `just sbom` (`nix run .#sbom`) | CycloneDX + SPDX + CSV SBOM of the reference system closure via [`sbomnix`]. Output: `./sbom/`. |
| `just vuln-scan` (`nix run .#vuln-scan`) | CVE scan of the reference closure with `vulnxscan` (grype + osv-scanner + vulnix) and `vulnix`. Output: `./vuln-scan/`. **Needs network.** |
| `just security-vm` (`nix build .#security-vm-test`) | Boots a Marchyo VM and runs a [`lynis`] host-hardening audit (+ the `vuls` collector) inside it. **Needs KVM.** |
| `just security-scan` | Runs all three. |

Both scanner apps take an optional target, e.g. `nix run .#sbom -- /nix/store/…`
to scan an arbitrary store path instead of the reference system. Override the
output directories with `$SBOM_OUT` / `$VULN_OUT`.

## Why these aren't `nix flake check` checks

- **SBOM / vulnix / vulnxscan** query the host Nix store and download NVD/OSV/
  grype data — impure and online, so they run on the host as apps, not in the
  hermetic build sandbox.
- **The VM test** boots a real guest (KVM) and is heavy; it is exposed as the
  `security-vm-test` package and built on demand. Inside it, `lynis` gives a
  real offline hardening audit (the test asserts it ran and produced a report);
  `vuls` only exercises its collector because CVE correlation needs an online
  database.

## Files

- [`vm-test.nix`](vm-test.nix) — the `nixosTest` (`security-vm-test` package).
- [`sbom.nix`](sbom.nix) — the `sbom` app.
- [`vuln-scan.nix`](vuln-scan.nix) — the `vuln-scan` app.

[`sbomnix`]: https://github.com/tiiuae/sbomnix
[`lynis`]: https://cisofy.com/lynis/

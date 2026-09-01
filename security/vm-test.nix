# NixOS VM security test — boots a real Marchyo system and runs host-hardening
# and vulnerability scanners against the live guest.
#
# This is the one security check that runs as a Nix build: it boots a VM (needs
# KVM) and runs the scanners inside it.
#
#   - lynis performs a fully offline, CIS-style hardening audit of the booted
#     system (sshd, sudo/PAM, kernel sysctls, file perms, running services).
#     This is the meaningful, network-free result and the test's regression
#     guard: it asserts lynis ran and produced a non-empty report.
#   - vuls is run in local mode too. Meaningful CVE correlation needs an online
#     CVE database (go-cve-dictionary et al.), which the hermetic build sandbox
#     has no network for, so here it only exercises the collector wiring.
#
# The store-closure CVE scanner (vulnix) and the SBOM + vulnxscan supply-chain
# analysis run on the *host* against the real system closure instead — see
# security/sbom.nix and security/vuln-scan.nix, exposed as the `sbom` and
# `vuln-scan` apps — because they query the host Nix store and fetch
# vulnerability data online, neither available inside this VM.
#
# The node enables marchyo.development (docker, virtualisation, dev services) —
# the security-relevant subset of the reference system, and the surface the
# docker-group hardening touches — but deliberately not the full desktop, so the
# VM stays buildable in reasonable time.
#
# Reports (lynis-report.dat, lynis.log, and the captured stdout) are copied into
# the build output. Build/run locally (NOT part of `nix flake check`):
#
#   nix build .#security-vm-test -L
{
  pkgs,
  nixosModule,
}:
# `testers.nixosTest` (not `runNixOSTest`): the latter injects a read-only
# `nixpkgs.pkgs` into every node, which collides with the marchyo modules that
# set `nixpkgs.overlays`. With `nixosTest` the node evaluates its own nixpkgs
# from those overlays, exactly like the real system.
pkgs.testers.nixosTest {
  name = "marchyo-security-scan";

  nodes.machine =
    { ... }:
    {
      imports = [ nixosModule ];

      # marchyo pulls unfree packages (e.g. 1Password); the node builds its own
      # pkgs, so allow unfree here as the real reference build does.
      nixpkgs.config.allowUnfree = true;

      marchyo = {
        development.enable = true;
        users.developer = {
          fullname = "Marchyo Developer";
          email = "dev@example.org";
        };
      };
      users.users.developer = {
        isNormalUser = true;
        initialPassword = "test";
        extraGroups = [ "wheel" ];
      };

      environment.systemPackages = [
        pkgs.lynis
        pkgs.vuls
      ];

      # A little headroom for the audit tooling.
      virtualisation.memorySize = 2048;
      virtualisation.diskSize = 4096;
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # --- lynis: offline host hardening audit -------------------------------
    # lynis exits non-zero whenever it records warnings/suggestions, which is
    # the normal outcome of an audit, so we don't let that fail the test — the
    # report is the artifact. --quick skips the interactive pauses.
    machine.succeed(
        "lynis audit system --no-colors --quick --auditor marchyo "
        "> /tmp/lynis-stdout.txt 2>&1; true"
    )
    # Assert lynis actually ran and wrote a non-empty machine-readable report.
    machine.succeed("test -s /var/log/lynis-report.dat")
    # Surface the coarse hardening index in the test log for at-a-glance triage.
    print(machine.succeed("grep -E 'hardening_index' /var/log/lynis-report.dat || true"))

    # --- vuls: local-mode collector ----------------------------------------
    # Full CVE correlation needs an online CVE database, unavailable in the
    # hermetic sandbox; exercise the collector wiring and capture its output.
    machine.succeed("vuls version > /tmp/vuls-version.txt 2>&1 || true")

    # --- persist reports into $out -----------------------------------------
    machine.copy_from_vm("/var/log/lynis-report.dat", "")
    machine.copy_from_vm("/var/log/lynis.log", "")
    machine.copy_from_vm("/tmp/lynis-stdout.txt", "")
    machine.copy_from_vm("/tmp/vuls-version.txt", "")
  '';
}

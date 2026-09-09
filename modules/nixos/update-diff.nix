{ pkgs, ... }:
{
  # Informational closure diff shown during `nixos-rebuild switch`.
  #
  # preSwitchChecks fragments run under `set -e` and a nonzero return aborts the
  # switch, so the pipeline is terminated with `|| true`: a dix failure (an
  # unparsable store path, OOM, an upstream regression) must never be able to
  # block a rebuild over a cosmetic diff.
  system.preSwitchChecks.update-diff = ''
    incoming="''${1-}"
    if [[ -e /run/current-system && -e "''${incoming-}" ]]; then
      echo "--- diff to current-system"
      ${pkgs.dix}/bin/dix /run/current-system "''${incoming-}" || true
      echo "---"
    fi
  '';
}

# Per-user qalculate (qalc) — calculator REPL.
#
# Replaces the system-level libqalculate package that lived in
# modules/nixos/packages.nix (tuiTools). Installed unconditionally for every
# marchyo user via Home-Manager's programs.qalculate.
_: {
  programs.qalculate.enable = true;
}

# System-level dictation wiring. The per-user services live in
# modules/home/dictation.nix and modules/home/voxtype.nix (home-manager).
#
# - voxtype: the daemon's evdev push-to-talk hotkey reads /dev/input, so users
#   join the `input` group (only when that hotkey is on).
# - superwhisper: its setup script links the app payload from
#   /run/current-system/sw, so the package is a system package. Evaluation
#   fails unless unfree packages are allowed.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.dictation;
  mUsers = lib.filterAttrs (_name: user: user.enable) config.marchyo.users;

  pkgCfg = config.nixpkgs.config;
  unfreeAllowed =
    (pkgCfg.allowUnfree or false)
    || (pkgCfg ? allowUnfreePredicate && pkgCfg.allowUnfreePredicate pkgs.superwhisper);
  isVoxtype = cfg.backend == "voxtype";
  isSuperwhisper = cfg.backend == "superwhisper";
in
{
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = !isSuperwhisper || unfreeAllowed;
            message = ''
              marchyo.dictation.backend = "superwhisper" needs unfree packages: Superwhisper is
              proprietary software. Set nixpkgs.config.allowUnfree = true (or allow the
              superwhisper package in nixpkgs.config.allowUnfreePredicate), or choose
              marchyo.dictation.backend = "voxtype" or "hex".
            '';
          }
        ];
      }

      (lib.mkIf (isVoxtype && cfg.pushToTalk.enable) {
        # extraGroups list-merges with the base groups set in modules/nixos/system.nix.
        users.users = lib.mapAttrs (_name: _user: {
          extraGroups = [ "input" ];
        }) mUsers;
      })

      (lib.mkIf (isSuperwhisper && unfreeAllowed) {
        environment.systemPackages = [ pkgs.superwhisper ];
        environment.pathsToLink = [ "/share/superwhisper" ];
      })
    ]
  );
}

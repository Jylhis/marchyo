# System-level Vicinae wiring. The launcher itself is configured in
# modules/home/vicinae.nix (settings, themes, the user service), but keystroke
# injection needs a privileged helper and that half only exists at NixOS scope.
#
# Vicinae's input-server helper writes to /dev/uinput, which is root:root 0660,
# so the stock store binary cannot open it. Upstream ships a NixOS module
# (`vicinae.nixosModules.default`, imported in outputs.nix) that installs
# /run/wrappers/bin/vicinae-input-server with cap_dac_override+ep. That option
# defaults to `true` upstream, hence the mkDefault gate here: without it every
# marchyo NixOS host — headless ones included — would grow the wrapper.
#
# The wrapper alone is not enough: the daemon locates helpers with
# findHelperProgram(), which only searches store-relative paths and never
# /run/wrappers/bin. modules/home/vicinae.nix completes the wiring by exporting
# VICINAE_INPUT_SERVER_BIN. Both halves are gated on the same option.
#
# Deliberately NOT wrapped in mkIf: upstream's option default is `true`, so a
# conditional assignment would leave headless hosts falling back to it. The
# desktop/launcher gates are folded into the value instead.
{ config, lib, ... }:
let
  cfg = config.marchyo;
in
{
  config.programs.vicinae.input-server.enable = lib.mkDefault (
    cfg.desktop.enable && cfg.launcher.enable && cfg.launcher.inputServer.enable
  );
}

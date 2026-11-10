# OBS, Kdenlive and lazydocker are not installed by default, even with the
# desktop, media and development flags on.
{ lib, ... }:
let
  hasPkg = name: cfg: lib.any (p: lib.getName p == name) cfg.environment.systemPackages;
in
{
  refs = {
    full = {
      eval-app-defaults-no-obs = cfg: !(hasPkg "obs-studio" cfg);
      eval-app-defaults-no-kdenlive = cfg: !(hasPkg "kdenlive" cfg);
    };
    headless-dev.eval-app-defaults-no-lazydocker = cfg: !(hasPkg "lazydocker" cfg);
  };
}

# btop: settings are mkDefault values, and the GPU box follows the listed
# vendors that btop can read (Intel and AMD through sysfs).
_:
let
  boxes = c: c.home-manager.users.testuser.programs.btop.settings.shown_boxes;
in
{
  refs = {
    # No vendors listed.
    desktop.eval-btop-boxes-default = c: boxes c == "cpu mem net proc";

    # desktop-tweaks: vendors = [ "intel" ].
    desktop-tweaks.eval-btop-boxes-gpu-intel = c: boxes c == "cpu mem net proc gpu0";

    # amd-tweaks: vendors = [ "amd" ].
    amd-tweaks.eval-btop-boxes-gpu-amd = c: boxes c == "cpu mem net proc gpu0";

    # nvidia-tweaks: NVML cannot load for the nixpkgs btop, so no GPU box.
    nvidia-tweaks.eval-btop-boxes-nvidia-only = c: boxes c == "cpu mem net proc";

    # headless-tweaks-4 sets shown_boxes without lib.mkForce.
    headless-tweaks-4.eval-btop-settings-overridable = c: boxes c == "cpu proc";
  };

  refConfig.headless-tweaks-4.home-manager.users.testuser.programs.btop.settings.shown_boxes =
    "cpu proc";
}

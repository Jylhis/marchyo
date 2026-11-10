# Upstream-option ports evaluate on a minimal host: minimal-tweaks enables
# programs.slack (with settings) and programs.solaar.
_: {
  refs.minimal-tweaks = {
    eval-slack = cfg: cfg.programs.slack.enable;
    eval-slack-settings = cfg: cfg.programs.slack.settings.DefaultSignInTeam == "example";
    eval-logitech = cfg: cfg.programs.solaar.enable;
  };

  refConfig.minimal-tweaks.programs = {
    slack = {
      enable = true;
      settings = {
        DefaultSignInTeam = "example";
        HardwareAcceleration = false;
      };
    };
    solaar.enable = true;
  };
}

{ helpers, lib, ... }:
let
  inherit (helpers) hyprEntriesText;
  restores =
    cfg:
    lib.hasInfix "marchyo runtime restore" (
      hyprEntriesText cfg.home-manager.users.testuser.wayland.windowManager.hyprland.settings.on
    );
in
{
  refs = {
    # CLI module: defaults to enabled, installs `marchyo` system-wide.
    headless.eval-cli-default = cfg: cfg.marchyo.cli.enable;

    # CLI module: explicitly disabled (headless-tweaks: marchyo.cli.enable = false).
    headless-tweaks.eval-cli-disabled = cfg: !cfg.marchyo.cli.enable;

    # CLI module: marchyoCliState merges into config.marchyo.* with mkDefault
    # (headless-tweaks-2: marchyoCliState.theme.variant = "light").
    # Note: marchyoCliState is a top-level option (not under marchyo.*) on
    # purpose to avoid a self-cycle in cli-state.nix.
    headless-tweaks-2.eval-cli-with-state = cfg: cfg.marchyo.theme.variant == "light";

    # With desktop + cli enabled (both default true for cli), the Hyprland
    # session restores CLI runtime overrides at startup.
    desktop.eval-cli-runtime-restore = restores;

    # marchyoCliState can append CLI-managed webapps additively: extraApps
    # entries land in the generated launcher set without replacing the
    # default marchyo.webapps.apps list (desktop-tweaks adds Figma).
    desktop-tweaks.eval-cli-webapp-extra =
      cfg:
      let
        apps = cfg.marchyo.webapps.apps ++ cfg.marchyo.webapps.extraApps;
      in
      builtins.any (a: a.name == "Figma") apps && builtins.any (a: a.name == "GitHub") apps;

    # cli.enable = false must also drop the startup-hook entry (desktop-tweaks-2).
    desktop-tweaks-2.eval-cli-disabled-no-restore = cfg: !(restores cfg);
  };

  refConfig = {
    headless-tweaks.marchyo.cli.enable = false;
    headless-tweaks-2.marchyoCliState.theme.variant = "light";
    desktop-tweaks.marchyoCliState.webapps.extraApps = [
      {
        name = "Figma";
        url = "https://figma.com/";
        key = "F";
      }
    ];
    desktop-tweaks-2.marchyo.cli.enable = false;
  };
}

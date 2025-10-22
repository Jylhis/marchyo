{
  lib,
  config,
  osConfig,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = if osConfig ? marchyo then osConfig.marchyo.theme else null;
  colors = if config ? colorScheme then config.colorScheme.palette else null;
  hex = color: "#${color}";
in
{
  config = {
    programs.k9s = {
      enable = true;
      settings = mkIf (cfg != null && cfg.enable && colors != null) {
        ui = {
          skin = "base16";
        };
      };
      skins = mkIf (cfg != null && cfg.enable && colors != null) {
        base16 = {
          k9s = {
            body = {
              fgColor = hex colors.base05;
              bgColor = "default";
              logoColor = hex colors.base0D;
            };
            prompt = {
              fgColor = hex colors.base05;
              bgColor = hex colors.base00;
              suggestColor = hex colors.base0D;
            };
            info = {
              fgColor = hex colors.base0C;
              sectionColor = hex colors.base05;
            };
            dialog = {
              fgColor = hex colors.base05;
              bgColor = hex colors.base00;
              buttonFgColor = hex colors.base00;
              buttonBgColor = hex colors.base0D;
              buttonFocusFgColor = hex colors.base00;
              buttonFocusBgColor = hex colors.base0C;
              labelFgColor = hex colors.base0A;
              fieldFgColor = hex colors.base05;
            };
            frame = {
              border = {
                fgColor = hex colors.base03;
                focusColor = hex colors.base0D;
              };
              menu = {
                fgColor = hex colors.base05;
                keyColor = hex colors.base0D;
                numKeyColor = hex colors.base0D;
              };
              crumbs = {
                fgColor = hex colors.base05;
                bgColor = hex colors.base01;
                activeColor = hex colors.base0D;
              };
              status = {
                newColor = hex colors.base0C;
                modifyColor = hex colors.base0D;
                addColor = hex colors.base0B;
                errorColor = hex colors.base08;
                highlightColor = hex colors.base0A;
                killColor = hex colors.base03;
                completedColor = hex colors.base03;
              };
              title = {
                fgColor = hex colors.base05;
                bgColor = hex colors.base01;
                highlightColor = hex colors.base0D;
                counterColor = hex colors.base0C;
                filterColor = hex colors.base0A;
              };
            };
            views = {
              charts = {
                bgColor = "default";
                dialBgColor = hex colors.base01;
                defaultDialColors = [
                  (hex colors.base0D)
                  (hex colors.base08)
                ];
                defaultChartColors = [
                  (hex colors.base0D)
                  (hex colors.base08)
                ];
              };
              table = {
                fgColor = hex colors.base05;
                bgColor = "default";
                cursorFgColor = hex colors.base00;
                cursorBgColor = hex colors.base0D;
                markColor = hex colors.base0A;
                header = {
                  fgColor = hex colors.base05;
                  bgColor = hex colors.base01;
                  sorterColor = hex colors.base0C;
                };
              };
              xray = {
                fgColor = hex colors.base05;
                bgColor = "default";
                cursorColor = hex colors.base0D;
                graphicColor = hex colors.base0D;
                showIcons = false;
              };
              yaml = {
                keyColor = hex colors.base0D;
                colonColor = hex colors.base03;
                valueColor = hex colors.base05;
              };
              logs = {
                fgColor = hex colors.base05;
                bgColor = "default";
                indicator = {
                  fgColor = hex colors.base0D;
                  bgColor = "default";
                  toggleOnColor = hex colors.base0B;
                  toggleOffColor = hex colors.base03;
                };
              };
            };
          };
        };
      };
    };
  };
}

# k9s with jylhis/base16 colors. The skin mirrors the retired Stylix k9s
# target's slot mapping exactly (it is what is on screen today), with one
# substitution: its base11 dialog focus color does not exist in catalog
# schemes, so base00 stands in. Slots come from
# modules/generic/theme-slots.nix (Jylhis pair by variant, or
# marchyo.theme.scheme's catalog palette).
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  theme = (osConfig.marchyo or { }).theme or { };
  themeEnabled = theme.enable or true;
  s = import ../generic/theme-slots.nix {
    inherit pkgs lib;
    variant = theme.variant or "dark";
    scheme = theme.scheme or null;
  };
in
{
  config = {
    programs.k9s = {
      enable = true;
      settings.ui.skin = lib.mkIf themeEnabled "jylhis";
      skins.jylhis.k9s = with s; {
        body = {
          fgColor = base05;
          bgColor = "default";
          logoColor = base0C;
        };

        prompt = {
          fgColor = base05;
          bgColor = "default";
          suggestColor = base02;
        };

        info = {
          fgColor = base0B;
          sectionColor = base05;
        };

        dialog = {
          fgColor = base05;
          bgColor = base01;
          buttonFgColor = base05;
          buttonBgColor = base02;
          buttonFocusFgColor = base00;
          buttonFocusBgColor = base0B;
          labelFgColor = base0A;
          fieldFgColor = base05;
        };

        frame = {
          border = {
            fgColor = base02;
            focusColor = base01;
          };

          menu = {
            fgColor = base05;
            keyColor = base0B;
            numKeyColor = base0B;
          };

          crumbs = {
            fgColor = base05;
            bgColor = base01;
            activeColor = base02;
          };

          status = {
            newColor = base0C;
            modifyColor = base09;
            addColor = base0B;
            errorColor = base08;
            highlightcolor = base0A;
            killColor = base03;
            completedColor = base03;
          };

          title = {
            fgColor = base05;
            bgColor = base01;
            highlightColor = base0A;
            counterColor = base0C;
            filterColor = base0B;
          };
        };

        views = {
          charts = {
            bgColor = "default";
            defaultDialColors = [
              base0C
              base0D
            ];
            defaultChartColors = [
              base0C
              base0D
            ];
          };

          table = {
            fgColor = base05;
            bgColor = "default";
            header = {
              fgColor = base05;
              bgColor = "default";
              sorterColor = base08;
            };
          };

          xray = {
            fgColor = base05;
            bgColor = "default";
            cursorColor = base01;
            graphicColor = base0C;
            showIcons = false;
          };

          yaml = {
            keyColor = base08;
            colonColor = base05;
            valueColor = base0B;
          };

          logs = {
            fgColor = base05;
            bgColor = "default";
            indicator = {
              fgColor = base05;
              bgColor = "default";
              toggleOnColor = base0B;
              toggleOffColor = base04;
            };
          };

          help = {
            fgColor = base05;
            bgColor = "default";
            indicator.fgColor = base0D;
          };
        };
      };
    };
  };
}

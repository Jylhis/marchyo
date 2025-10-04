{ config, lib, ... }:
{
  options.marchyo.fastfetch = {
    enable = lib.mkEnableOption "fastfetch system information tool" // {
      default = true;
    };
  };

  config = lib.mkIf config.marchyo.fastfetch.enable {
    programs.fastfetch = {
      enable = true;
      settings = {
        logo = {
          type = "auto";
          padding = {
            top = 1;
            left = 2;
          };
        };

        display = {
          separator = " → ";
        };

        modules = [
          {
            type = "custom";
            format = "┌───────────── Hardware ─────────────┐";
          }
          {
            type = "host";
            key = "  ";
            keyColor = "green";
          }
          {
            type = "cpu";
            key = "  ";
            keyColor = "green";
          }
          {
            type = "gpu";
            key = "  ";
            keyColor = "green";
          }
          {
            type = "display";
            key = " 󰍹 ";
            keyColor = "green";
          }
          {
            type = "disk";
            key = " 󰋊 ";
            keyColor = "green";
          }
          {
            type = "memory";
            key = " 󰑭 ";
            keyColor = "green";
          }
          {
            type = "swap";
            key = " 󰓡 ";
            keyColor = "green";
          }
          {
            type = "custom";
            format = "├───────────── Software ─────────────┤";
          }
          {
            type = "os";
            key = "  ";
            keyColor = "blue";
          }
          {
            type = "kernel";
            key = "  ";
            keyColor = "blue";
          }
          {
            type = "wm";
            key = "  ";
            keyColor = "blue";
          }
          {
            type = "de";
            key = "  ";
            keyColor = "blue";
          }
          {
            type = "terminal";
            key = "  ";
            keyColor = "blue";
          }
          {
            type = "packages";
            key = " 󰏖 ";
            keyColor = "blue";
          }
          {
            type = "wmtheme";
            key = " 󰉼 ";
            keyColor = "blue";
          }
          {
            type = "theme";
            key = " 󰔎 ";
            keyColor = "blue";
          }
          {
            type = "terminalfont";
            key = "  ";
            keyColor = "blue";
          }
          {
            type = "custom";
            format = "└────────────────────────────────────┘";
          }
          {
            type = "uptime";
            key = " 󰅐 ";
            keyColor = "magenta";
          }
        ];
      };
    };
  };
}

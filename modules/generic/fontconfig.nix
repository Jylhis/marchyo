{ options, ... }:
{
  config =
    if (options ? fonts && options.fonts ? fontconfig) then
      {
        fonts.fontconfig = {
          enable = true;
          defaultFonts = {
            serif = [ "Liberation Serif" ];
            sansSerif = [ "Liberation Sans" ];
            monospace = [ "CaskaydiaMono Nerd Font" ];
          };
        };
      }
    else
      { };
}

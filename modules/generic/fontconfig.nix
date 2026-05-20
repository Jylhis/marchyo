{ options, ... }:
{
  config =
    if (options ? fonts && options.fonts ? fontconfig) then
      {
        fonts.fontconfig = {
          enable = true;
          defaultFonts = {
            serif = [ "Literata" ];
            sansSerif = [ "Liberation Sans" ];
            monospace = [ "JetBrainsMono Nerd Font" ];
          };
        };
      }
    else
      { };
}

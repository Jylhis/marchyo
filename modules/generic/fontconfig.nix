{ options, ... }:
{
  config =
    if (options ? fonts && options.fonts ? fontconfig) then
      {
        fonts.fontconfig = {
          enable = true;
          defaultFonts = {
            serif = [ "Zilla Slab" ];
            sansSerif = [ "Hanken Grotesk" ];
            monospace = [ "BlexMono Nerd Font" ];
          };
        };
      }
    else
      { };
}

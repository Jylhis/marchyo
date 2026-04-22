{ config, options, ... }:
{
  config.stylix = {
    inherit (config.marchyo.theme) enable;
    polarity = config.marchyo.theme.variant;
  }
  // (
    if (options ? stylix && options.stylix ? targets && options.stylix.targets ? plymouth) then
      { targets.plymouth.enable = false; }
    else
      { }
  );
}

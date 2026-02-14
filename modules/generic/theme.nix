{ config, ... }:
{
  config.stylix = {

    inherit (config.marchyo.theme) enable;
    polarity = config.marchyo.theme.variant;
  };

}

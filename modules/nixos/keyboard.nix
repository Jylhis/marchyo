{
  lib,
  config,
  ...
}:
let
  cfg = config.marchyo.keyboard;
in
{
  config = {
    # Apply marchyo keyboard configuration to system level
    # This ensures console/TTY and X11 applications respect keyboard settings
    services.xserver.xkb = {
      layout = lib.mkDefault (lib.concatStringsSep "," cfg.layouts);

      # Apply variant only to first layout when multiple layouts exist
      # Example: layouts=["us","fi"] variant="intl" → variant="intl,"
      variant = lib.mkDefault (
        if cfg.variant != "" then
          lib.concatStringsSep "," ([ cfg.variant ] ++ (lib.replicate ((lib.length cfg.layouts) - 1) ""))
        else
          ""
      );

      # Convert list of options to comma-separated string
      options = lib.mkDefault (lib.concatStringsSep "," cfg.options);
    };
  };
}

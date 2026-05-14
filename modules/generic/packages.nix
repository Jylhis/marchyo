{
  lib,
  options,
  ...
}:
let
  hasProgram = name: options ? programs && options.programs ? ${name};
in
{
  programs =
    lib.optionalAttrs (hasProgram "zoxide") {
      zoxide = {
        enable = true;
      }
      // lib.optionalAttrs (options.programs.zoxide ? options) {
        options = [ "--cmd cd" ];
      };
    }
    // lib.optionalAttrs (hasProgram "nh") { nh.enable = true; }
    // lib.optionalAttrs (hasProgram "trippy") { trippy.enable = true; };
}

{
  options,
  ...
}:
let
  hasProgram = name: options ? programs && options.programs ? ${name};
in
{
  programs =
    (if hasProgram "zoxide" then { zoxide.enable = true; } else { })
    // (if hasProgram "nh" then { nh.enable = true; } else { })
    // (if hasProgram "trippy" then { trippy.enable = true; } else { });
}

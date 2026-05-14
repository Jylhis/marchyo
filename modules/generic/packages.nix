{
  options,
  ...
}:
let
  hasProgram = name: options ? programs && options.programs ? ${name};
in
{
  programs =
    (
      if hasProgram "zoxide" then
        {
          zoxide =
            {
              enable = true;
            }
            // (
              if options.programs.zoxide ? options then
                {
                  options = [ "--cmd cd" ];
                }
              else
                { }
            );
        }
      else
        { }
    )
    // (if hasProgram "nh" then { nh.enable = true; } else { })
    // (if hasProgram "trippy" then { trippy.enable = true; } else { });
}

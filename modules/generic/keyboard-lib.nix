# Shared keyboard helper functions used by NixOS and Home Manager keyboard modules.
{
  # Normalize a layout entry (string or attrset) to a uniform structure.
  normalizeLayout =
    layout:
    if builtins.isString layout then
      {
        inherit layout;
        variant = "";
        ime = null;
        label = null;
      }
    else
      layout;
}

let
  inherit ((import ../../lib/default.nix)) getNixFilesExcept;
in
{
  imports = (getNixFilesExcept ./. "marchyo.nix") ++ (getNixFilesExcept ../generic "default.nix");
}

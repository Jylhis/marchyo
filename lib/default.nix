{
  getNixFilesExcept =
    path: _exclude_name:
    builtins.map (fn: ./${fn}) (
      builtins.filter (fn: fn != "default.nix") (builtins.attrNames (builtins.readDir path))
    );
}

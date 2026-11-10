{
  manual = {
    html.enable = true;
    manpages.enable = true;
  };
  # Link split HTML docs into the profile, as documentation.doc does for the
  # system profile, so http://localhost can list them.
  home.extraOutputsToInstall = [
    "doc"
    "devdoc"
  ];
  programs = {
    man.enable = true;
    info.enable = true;
  };
}

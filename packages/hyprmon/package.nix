{
  lib,
  buildGoModule,
  fetchFromGitHub,
  go,
}:

buildGoModule rec {
  pname = "hyprmon";
  version = "0.0.11";

  src = fetchFromGitHub {
    owner = "erans";
    repo = "hyprmon";
    rev = "v${version}";
    hash = "sha256-TuxBdN8sjj0lH4DCPtj83HI9FlBaqAmPlpttnKuf+9Y=";
  };
  postPatch = ''
    substituteInPlace go.mod \
      --replace-fail "go 1.25.1" "go ${go.version}"
  '';
  vendorHash = "sha256-sD+zpHg7hrsmosledXJ17bdFk+dSVTYitzJ7RuYJAIQ=";

  meta = {
    description = "TUI monitor configuration tool for Hyprland with visual layout, drag-and-drop, and profile management";
    homepage = "https://github.com/erans/hyprmon";
    license = lib.licenses.asl20;
    maintainers = [ ];
    mainProgram = "hyprmon";
  };
}

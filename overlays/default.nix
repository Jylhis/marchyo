{ inputs }:
final: _prev: {
  vicinae = inputs.vicinae.packages.${final.stdenv.hostPlatform.system}.default;
  noctalia = inputs.noctalia.packages.${final.stdenv.hostPlatform.system}.default;
  worktrunk = inputs.worktrunk.packages.${final.stdenv.hostPlatform.system}.default;
}

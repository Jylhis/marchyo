{ inputs }:
final: _prev: {
  vicinae = inputs.vicinae.packages.${final.system}.default;
  noctalia = inputs.noctalia.packages.${final.system}.default;
  worktrunk = inputs.worktrunk.packages.${final.system}.default;
}

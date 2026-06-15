# Shared readers for marchyo.ai config from a Home Manager osConfig.
#
# The marchyo.ai impl modules (modules/home/ai-*.nix) and hyprland.nix all read
# the same osConfig.marchyo.ai values defensively (osConfig is {} for standalone
# Home Manager configs). Centralising the reads and the OpenRouter option-default
# literals here keeps them from drifting out of sync with modules/nixos/options/ai.nix.
osConfig:
let
  aiCfg = (osConfig.marchyo or { }).ai or { };
  orCfg = aiCfg.openrouter or { };
in
{
  inherit aiCfg orCfg;
  enable = aiCfg.enable or false;
  baseUrl = orCfg.baseUrl or "https://openrouter.ai/api/v1";
  keyFile = if (orCfg.apiKeyFile or null) == null then "" else toString orCfg.apiKeyFile;
  # ai.enable && ai.<sub>.enable, with the sub-feature's own default.
  featureEnabled = sub: default: (aiCfg.enable or false) && (aiCfg.${sub}.enable or default);
}

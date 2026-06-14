# Per-user Emacs with gptel wired to OpenRouter.
#
# Enabled when marchyo.ai.enable and Emacs is the selected editor
# (marchyo.defaults.editor or .terminalEditor == "emacs"). Installs gptel and
# configures it to talk to OpenRouter. The API key is read directly from
# marchyo.ai.openrouter.apiKeyFile at request time (a function passed to
# gptel-make-openai), so it works for both terminal- and Hyprland-launched
# Emacs and never enters the Nix store.
{
  osConfig ? { },
  lib,
  ...
}:
let
  marchyo = osConfig.marchyo or { };
  defaults = marchyo.defaults or { };
  aiCfg = marchyo.ai or { };
  orCfg = aiCfg.openrouter or { };

  emacsSelected = (defaults.editor or null) == "emacs" || (defaults.terminalEditor or null) == "emacs";
  enabled = (aiCfg.enable or false) && emacsSelected;

  defaultModel = orCfg.defaultModel or "anthropic/claude-sonnet-4";
  keyFile = if (orCfg.apiKeyFile or null) == null then "" else toString orCfg.apiKeyFile;
in
{
  config = lib.mkIf enabled {
    programs.emacs = {
      enable = true;
      extraPackages = epkgs: [ epkgs.gptel ];
      extraConfig = ''
        ;; marchyo: gptel via OpenRouter (BYOK)
        (with-eval-after-load 'gptel
          (setq gptel-model '${defaultModel})
          (setq gptel-backend
                (gptel-make-openai "OpenRouter"
                  :host "openrouter.ai"
                  :endpoint "/api/v1/chat/completions"
                  :stream t
                  :key (lambda ()
                         (when (file-readable-p "${keyFile}")
                           (string-trim
                            (with-temp-buffer
                              (insert-file-contents "${keyFile}")
                              (buffer-string)))))
                  :models '(${defaultModel}))))
        (autoload 'gptel "gptel" "Start a gptel chat session." t)
      '';
    };
  };
}

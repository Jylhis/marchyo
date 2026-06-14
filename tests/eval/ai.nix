{ helpers, ... }:
let
  inherit (helpers) testNixOS testNixOSFails withTestUser;
in
{
  # OpenRouter BYOK enabled with a key file + Emacs editor evaluates clean.
  eval-ai-openrouter = testNixOS "ai-openrouter" (withTestUser {
    marchyo.desktop.enable = true;
    marchyo.defaults.editor = "emacs";
    marchyo.ai = {
      enable = true;
      openrouter.apiKeyFile = "/run/secrets/openrouter-api-key";
    };
  });

  # AI options present but disabled — default state must still evaluate.
  eval-ai-disabled = testNixOS "ai-disabled" (withTestUser {
    marchyo.ai.enable = false;
  });

  # Enabling without an API key file fails the required-key assertion.
  eval-ai-missing-key = testNixOSFails "ai-missing-key" "openrouter.apiKeyFile" (withTestUser {
    marchyo.ai.enable = true;
  });

  # Local inference is not implemented yet — enabling it must fail.
  eval-ai-local-asserts = testNixOSFails "ai-local-asserts" "local inference is not yet implemented" (withTestUser {
    marchyo.ai = {
      enable = true;
      openrouter.apiKeyFile = "/run/secrets/openrouter-api-key";
      local.enable = true;
    };
  });
}

{ helpers, ... }:
let
  inherit (helpers) testNixOS testNixOSFails withTestUser;
  withKey =
    extra:
    withTestUser {
      marchyo.ai = {
        enable = true;
        openrouter.apiKeyFile = "/run/secrets/openrouter-api-key";
      }
      // extra;
    };
in
{
  # OpenRouter BYOK enabled with a key file evaluates clean.
  eval-ai-openrouter = testNixOS "ai-openrouter" (withTestUser {
    marchyo.desktop.enable = true;
    marchyo.ai = {
      enable = true;
      openrouter.apiKeyFile = "/run/secrets/openrouter-api-key";
    };
  });

  # AI options present but disabled — default state must still evaluate.
  eval-ai-disabled = testNixOS "ai-disabled" (withTestUser {
    marchyo.ai.enable = false;
  });

  # Routing default table evaluates; a per-bucket override evaluates.
  eval-ai-routing-override = testNixOS "ai-routing-override" (withKey {
    routing.tasks.frontier.model = "openai/gpt-5.5";
    routing.tools.aichat = "frontier";
  });

  # OpenViking context layer evaluates.
  eval-ai-context = testNixOS "ai-context" (withKey {
    context.enable = true;
  });

  # Everything on together evaluates.
  eval-ai-full = testNixOS "ai-full" (withTestUser {
    marchyo.desktop.enable = true;
    marchyo.ai = {
      enable = true;
      openrouter.apiKeyFile = "/run/secrets/openrouter-api-key";
      context.enable = true;
      skills.enable = true;
      mcp.enable = true;
    };
  });

  # Enabling without an API key file fails the required-key assertion.
  eval-ai-missing-key = testNixOSFails "ai-missing-key" "openrouter.apiKeyFile" (withTestUser {
    marchyo.ai.enable = true;
  });

  # Local inference is not implemented yet — enabling it must fail.
  eval-ai-local-asserts =
    testNixOSFails "ai-local-asserts" "local inference is not yet implemented"
      (withKey {
        local.enable = true;
      });
}

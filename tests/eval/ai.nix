{ helpers, lib, ... }:
let
  inherit (helpers)
    testNixOS
    testNixOSCheck
    testNixOSFails
    withTestUser
    ;
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
    routing.tools.pi = "frontier";
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

  # The pi provider extension is TypeScript, so the key has to be read from the
  # environment at runtime. A "$OPENROUTER_API_KEY" string literal is passed
  # through verbatim as the credential (nothing expands it) and every OpenRouter
  # request then fails auth.
  eval-ai-pi-extension-reads-env = testNixOSCheck "ai-pi-extension-reads-env" (
    cfg:
    let
      ext = cfg.home-manager.users.testuser.home.file.".pi/agent/extensions/marchyo-openrouter.ts".text;
    in
    lib.hasInfix "apiKey: process.env.OPENROUTER_API_KEY" ext
    && !(lib.hasInfix ''apiKey: "$OPENROUTER_API_KEY"'' ext)
  ) (withKey { });

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

{ lib, ... }:
let
  inherit (lib) mkOption types;

  userOpts =
    { name, ... }:
    {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
          example = false;
          description = ''
            If set to false, the user account will not have any Marchyo stuff.
          '';
        };

        name = mkOption {
          type = types.str;
          default = name;
          description = ''
            The name of the user account.
            Use `users.users.{name}.name` to reference it.
          '';
        };
        fullname = mkOption {
          type = types.str;
          description = "Your full name";
        };
        email = mkOption {
          type = types.str;
          description = "Your email address";
        };

        wakatimeApiKeyFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          example = "/run/secrets/wakatime-api-key";
          description = ''
            Path to a user-readable file containing the WakaTime API key for
            editor heartbeat tracking. Preferred over {option}`wakatimeApiKey`
            because the key is read at home-manager activation time and never
            enters the world-readable Nix store. When set together with
            marchyo.tracking.editor.enable, a ~/.wakatime.cfg is generated.
          '';
        };

        wakatimeApiKey = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            WakaTime API key for editor heartbeat tracking.

            ::: {.warning}
            This value is written verbatim into the Nix store and is therefore
            readable by every local user and process. Prefer
            {option}`wakatimeApiKeyFile`, which keeps the secret out of the store.
            :::

            When set together with marchyo.tracking.editor.enable, a
            ~/.wakatime.cfg is generated and WAKATIME_API_KEY is exported.
          '';
        };
      };
    };
in
{
  options.marchyo.users = mkOption {
    default = { };
    type = with types; attrsOf (submodule userOpts);
    description = ''
      Marchyo user configuration.
      Defines users with associated metadata like fullname and email.
    '';
  };
}

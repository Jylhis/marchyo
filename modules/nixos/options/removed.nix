# Retired options. A removed entry makes a definition fail with a pointer to
# what replaces it, instead of an unknown-option error; a renamed entry
# forwards the definition to the upstream option with a warning.
{ config, lib, ... }:
let
  removed = path: why: lib.mkRemovedOptionModule ([ "marchyo" ] ++ path) why;
  renamed = path: to: lib.mkRenamedOptionModule ([ "marchyo" ] ++ path) to;

  # mkRemovedOptionModule cannot reach inside the marchyo.users attrsOf
  # submodule, so its retired fields are hidden null options with an
  # assertion each.
  removedUserFields = {
    uid = name: "marchyo.users.${name}.uid has been removed; set users.users.${name}.uid instead.";
    name =
      name:
      "marchyo.users.${name}.name has been removed; it was never read (the attribute name is the account name).";
  };

  vicinae = "Vicinae is no longer part of marchyo; the in-shell launcher of marchyo.shell replaces it.";
  aiTooling =
    what:
    "${what} is not carried in marchyo. marchyo.defaults.aiAgent (with marchyo.development.enable) still installs one agent CLI and sets $AI_AGENT; install anything else on the host.";
in
{
  options.marchyo.users = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = lib.mapAttrs (
          _: _:
          lib.mkOption {
            type = lib.types.unspecified;
            default = null;
            visible = false;
          }
        ) removedUserFields;
      }
    );
  };

  config.assertions = lib.concatLists (
    lib.mapAttrsToList (
      name: user:
      lib.mapAttrsToList (field: message: {
        assertion = user.${field} == null;
        message = message name;
      }) removedUserFields
    ) config.marchyo.users
  );

  imports = [
    (removed [ "launcher" "keybinding" ] vicinae)
    (removed [ "launcher" "inputServer" ] vicinae)
    (removed [ "launcher" "telemetry" ] vicinae)
    (removed [ "launcher" "declutter" ] vicinae)
    (removed [ "launcher" "settings" ] vicinae)
    (removed [
      "osd"
      "enable"
    ] "SwayOSD is no longer part of marchyo; the Marchyo shell (marchyo.shell) draws the OSD.")
    (removed [
      "gaming"
    ] "The gaming bundle is no longer part of marchyo; enable programs.steam and friends on the host.")
    (removed [
      "console"
      "kmscon"
    ] "kmscon is no longer part of marchyo; configure services.kmscon on the host.")
    (removed [
      "snapshots"
    ] "Snapper snapshots are no longer part of marchyo; configure services.snapper on the host.")
    (removed
      [
        "shell"
        "devPlugins"
      ]
      "The omarchy plugin layer and `marchyo plugin dev` are not carried in marchyo; declare plugins with marchyo.shell.plugins and rebuild."
    )
    (removed
      [
        "shell"
        "barPlugin"
      ]
      "Bar-replacing plugins are not carried in marchyo; the built-in bar is always used. Add bar-widget plugins to marchyo.shell.settings.bar.layout instead."
    )
    (removed [ "ai" "agents" ] (aiTooling "The multi-agent install list (marchyo.ai.agents)"))
    (removed [ "ai" "accounts" ] (aiTooling "Agent account switching (marchyo.ai.accounts)"))
    (removed [ "ai" "skills" ] (aiTooling "The Marchyo agent skills (marchyo.ai.skills)"))
    (removed [ "ai" "crashCapture" ] (
      aiTooling "Crash capture with an agent (marchyo.ai.crashCapture)"
    ))
    (removed [ "ai" "herdr" ] (aiTooling "herdr (marchyo.ai.herdr)"))
    (removed [ "ai" "amp" ] (aiTooling "Amp (marchyo.ai.amp)"))
    (removed [
      "ai"
      "local"
    ] "Local AI (Ollama) is not carried in marchyo; configure services.ollama on the host.")
    (removed
      [
        "audio"
        "tuner"
      ]
      "The omarchy speaker tuner is not carried in marchyo; tune PipeWire with services.pipewire.extraConfig on the host."
    )
    (removed [
      "hardware"
      "camlink"
    ] "The Cam Link 4K relay is not carried in marchyo; configure services.v4l2-relayd on the host.")
    (removed [
      "slack"
      "themeInjection"
    ] "Slack theme injection is not carried in marchyo; Slack keeps its own theme.")
    (removed
      [
        "keyboard"
        "legacyBinds"
      ]
      "The pre-Omarchy-4.5 bind layout is now the only Hyprland layout; drop marchyo.keyboard.legacyBinds."
    )
    (removed
      [
        "console"
        "enable"
      ]
      "The Quake-style agent console is not carried in marchyo; use a terminal or a special workspace bind on the host."
    )

    # Pass-through options: marchyo now sets the upstream option itself (at
    # lib.mkDefault where it has a marchyo default).
    (renamed [ "security" "firewall" "enable" ] [ "networking" "firewall" "enable" ])
    (renamed [ "power" "hibernation" "resumeDevice" ] [ "boot" "resumeDevice" ])
    # programs.solaar also turns on hardware.logitech.wireless.
    (renamed [ "hardware" "logitech" "enable" ] [ "programs" "solaar" "enable" ])
    (renamed [ "graphics" "nvidia" "open" ] [ "hardware" "nvidia" "open" ])
    (renamed
      [ "graphics" "nvidia" "powerManagement" ]
      [ "hardware" "nvidia" "powerManagement" "enable" ]
    )
    (renamed
      [ "graphics" "nvidia" "containerToolkit" "enable" ]
      [
        "hardware"
        "nvidia-container-toolkit"
        "enable"
      ]
    )
    (renamed [ "graphics" "amd" "overdrive" "enable" ] [ "hardware" "amdgpu" "overdrive" "enable" ])
    (removed [ "graphics" "nvidia" "package" ]
      "Set hardware.nvidia.package directly, e.g. config.boot.kernelPackages.nvidiaPackages.beta; marchyo defaults it from marchyo.graphics.nvidia.generation."
    )
    (removed [
      "performance"
      "kernel"
    ] "Set boot.kernelPackages directly, e.g. pkgs.linuxPackages_zen or pkgs.linuxPackages_latest.")
    (removed [ "nix" "caches" ]
      "Add caches to nix.settings.substituters and nix.settings.trusted-public-keys; marchyo's own list merges with them and ncro routes every substituter."
    )
    (renamed [ "nix" "router" "enable" ] [ "services" "ncro" "enable" ])
    (renamed [ "nix" "router" "port" ] [ "services" "ncro" "port" ])
    (renamed [ "nix" "router" "netrcFile" ] [ "services" "ncro" "netrcFile" ])
    (removed [ "nix" "router" "extraUpstreams" ]
      "Add the cache to nix.settings.substituters (ncro routes every substituter) or to services.ncro.settings.upstreams."
    )
    (renamed [ "services" "tailscale" "enable" ] [ "services" "tailscale" "enable" ])
    (renamed [ "services" "localsend" "enable" ] [ "programs" "localsend" "enable" ])
    (renamed [ "services" "localsend" "openFirewall" ] [ "programs" "localsend" "openFirewall" ])
  ];
}

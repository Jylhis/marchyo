# Retired options. Each entry makes a definition fail with a pointer to what
# replaces it, instead of an unknown-option error.
{ lib, ... }:
let
  removed = path: why: lib.mkRemovedOptionModule ([ "marchyo" ] ++ path) why;

  vicinae = "Vicinae is no longer part of marchyo; the in-shell launcher of marchyo.shell replaces it.";
  aiTooling =
    what:
    "${what} is not carried in marchyo. marchyo.defaults.aiAgent (with marchyo.development.enable) still installs one agent CLI and sets $AI_AGENT; install anything else on the host.";
in
{
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
        "console"
        "enable"
      ]
      "The Quake-style agent console is not carried in marchyo; use a terminal or a special workspace bind on the host."
    )
  ];
}

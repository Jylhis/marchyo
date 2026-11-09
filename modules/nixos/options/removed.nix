# Retired options. Each entry makes a definition fail with a pointer to what
# replaces it, instead of an unknown-option error.
{ lib, ... }:
let
  removed = path: why: lib.mkRemovedOptionModule ([ "marchyo" ] ++ path) why;

  vicinae = "Vicinae is no longer part of marchyo; the in-shell launcher of marchyo.shell replaces it.";
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
  ];
}

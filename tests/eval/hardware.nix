# Presence checks for the nixos-hardware passthrough (nixosModules.hardware).
#
# Deliberately does NOT evaluate any profile module — nixos-hardware profiles
# may assume real hardware (kernel modules, firmware, bus IDs) and some legacy
# attrs are `throw` tombstones. Attribute-presence checks (hasAttr, attrNames)
# never force the attr values, so the whole set stays lazy here.
{
  helpers,
  lib,
  nixosHardwareModules,
  ...
}:
let
  inherit (helpers) assertTest;
in
{
  test-hardware-passthrough-nonempty = assertTest "hardware-passthrough-nonempty" (
    builtins.attrNames nixosHardwareModules != [ ]
  ) "Expected nixosModules.hardware to re-export a non-empty nixos-hardware module set";

  # The curated profiles advertised in the workstation template and
  # docs/introduction.mdx must exist in the passthrough (guards against
  # upstream renames going unnoticed in our docs).
  test-hardware-passthrough-profiles =
    let
      advertised = [
        "lenovo-thinkpad-x1-9th-gen"
        "lenovo-thinkpad-t14-amd-gen5"
        "framework-13-7040-amd"
        "framework-16-7040-amd"
        "dell-xps-13-9310"
        "common-cpu-intel"
        "common-cpu-amd"
        "common-gpu-amd"
        "common-gpu-nvidia"
        "common-pc-ssd"
        "common-pc-laptop"
      ];
      missing = lib.filter (name: !(lib.hasAttr name nixosHardwareModules)) advertised;
      message = "Missing nixos-hardware profiles: ${lib.concatStringsSep ", " missing}";
    in
    assertTest "hardware-passthrough-profiles" (missing == [ ]) message;
}

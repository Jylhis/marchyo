{ helpers, ... }:
let
  inherit (helpers) testNixOS minimalConfig;
in
{
  eval-graphics-intel = testNixOS "graphics-intel" (
    minimalConfig
    // {
      marchyo.graphics.vendors = [ "intel" ];
    }
  );

  eval-graphics-amd = testNixOS "graphics-amd" (
    minimalConfig
    // {
      marchyo.graphics.vendors = [ "amd" ];
    }
  );

  eval-graphics-nvidia = testNixOS "graphics-nvidia" (
    minimalConfig
    // {
      marchyo.graphics.vendors = [ "nvidia" ];
    }
  );

  eval-graphics-prime-offload = testNixOS "graphics-prime-offload" (
    minimalConfig
    // {
      marchyo.graphics = {
        vendors = [
          "intel"
          "nvidia"
        ];
        prime = {
          enable = true;
          intelBusId = "PCI:0:2:0";
          nvidiaBusId = "PCI:1:0:0";
          mode = "offload";
        };
      };
    }
  );

  eval-graphics-prime-sync = testNixOS "graphics-prime-sync" (
    minimalConfig
    // {
      marchyo.graphics = {
        vendors = [
          "amd"
          "nvidia"
        ];
        prime = {
          enable = true;
          amdgpuBusId = "PCI:6:0:0";
          nvidiaBusId = "PCI:1:0:0";
          mode = "sync";
        };
      };
    }
  );

  # Empty vendors falls back to Intel on x86_64 for backward compatibility.
  eval-graphics-legacy = testNixOS "graphics-legacy" (
    minimalConfig
    // {
      marchyo.graphics.vendors = [ ];
    }
  );
}

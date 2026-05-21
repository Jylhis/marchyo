{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.graphics = {
    vendors = mkOption {
      type = types.listOf (
        types.enum [
          "intel"
          "amd"
          "nvidia"
        ]
      );
      default = [ ];
      example = [
        "intel"
        "nvidia"
      ];
      description = ''
        GPU vendors present in the system.
        - "intel": Intel integrated graphics (iGPU)
        - "amd": AMD GPUs (integrated or discrete)
        - "nvidia": NVIDIA discrete GPUs

        For hybrid graphics laptops, specify both vendors (e.g., ["intel" "nvidia"]).
        When empty, Intel packages are applied on x86_64 for backward compatibility.

        Find your GPU with: lspci | grep -E 'VGA|3D'
      '';
    };

    nvidia = {
      open = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Use NVIDIA's open-source kernel modules.
          Recommended for Turing (RTX 20xx) and newer GPUs.
          Required for RTX 50xx series.
          Set to false for older GPUs (Maxwell, Pascal, Volta).
        '';
      };

      powerManagement = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable experimental power management for NVIDIA GPUs.
          May improve battery life on laptops but can cause issues on some systems.
        '';
      };
    };

    prime = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable NVIDIA PRIME for hybrid graphics laptops.
          Requires both an integrated GPU (intel or amd) and nvidia in vendors.
        '';
      };

      intelBusId = mkOption {
        type = types.str;
        default = "";
        example = "PCI:0:2:0";
        description = ''
          PCI bus ID of the Intel integrated GPU.
          Find with: lspci | grep -E 'VGA|3D' | grep Intel
          Format: PCI:bus:device:function (convert hex to decimal)
        '';
      };

      amdgpuBusId = mkOption {
        type = types.str;
        default = "";
        example = "PCI:6:0:0";
        description = ''
          PCI bus ID of the AMD integrated GPU.
          Find with: lspci | grep -E 'VGA|3D' | grep AMD
          Format: PCI:bus:device:function (convert hex to decimal)
        '';
      };

      nvidiaBusId = mkOption {
        type = types.str;
        default = "";
        example = "PCI:1:0:0";
        description = ''
          PCI bus ID of the NVIDIA discrete GPU.
          Find with: lspci | grep -E 'VGA|3D' | grep NVIDIA
          Format: PCI:bus:device:function (convert hex to decimal)
        '';
      };

      mode = mkOption {
        type = types.enum [
          "offload"
          "sync"
          "reverse-sync"
        ];
        default = "offload";
        description = ''
          PRIME render mode:
          - "offload": On-demand rendering (default, power efficient).
            Use `nvidia-offload <command>` to run apps on dGPU.
          - "sync": Always use discrete GPU (best performance, more power).
          - "reverse-sync": iGPU for display, dGPU for compute.
        '';
      };
    };
  };
}

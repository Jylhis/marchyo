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
      generation = mkOption {
        type = types.enum [
          "turing-or-newer"
          "pre-turing"
        ];
        default = "turing-or-newer";
        description = ''
          NVIDIA GPU generation.
          - "turing-or-newer": RTX 20xx, GTX 16xx and newer (GPUs with a GSP).
            Uses the open kernel modules and the direct VA-API backend.
          - "pre-turing": Maxwell, Pascal and Volta.
            Uses the closed kernel modules, the 580 legacy driver and the EGL VA-API backend.

          The kernel modules and driver branch are set on `hardware.nvidia.open`
          and `hardware.nvidia.package` with `lib.mkDefault`; set those
          directly to override them.
        '';
      };

    };

    amd = {
      rocm = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable the ROCm compute stack (HIP and the OpenCL runtime).
            Links the runtime to `/opt/rocm` and adds Marchyo users to the
            `render` and `video` groups.
          '';
        };

        hsaOverrideGfxVersion = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "10.3.0";
          description = ''
            Value for `HSA_OVERRIDE_GFX_VERSION`.
            Set it to run ROCm on a GPU that ROCm does not officially support,
            for example "10.3.0" for RDNA2 or "11.0.0" for RDNA3.
          '';
        };
      };

      vaapi.enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Use the Mesa radeonsi driver for VA-API and VDPAU video acceleration.
          `LIBVA_DRIVER_NAME` is set to "radeonsi" only when AMD is the primary GPU.
        '';
      };
    };

    prime = {
      integratedOnlySpecialisation = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Add an `integrated-only` boot specialisation for hybrid laptops.
          It turns off PRIME, blacklists the nvidia and nouveau kernel modules,
          and removes the NVIDIA environment variables and the container toolkit.
          Select it in the systemd-boot menu; when the menu is hidden, hold Space at boot to show it.
        '';
      };

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

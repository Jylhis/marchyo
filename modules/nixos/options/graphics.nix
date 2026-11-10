{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.marchyo.graphics;

  vendor = types.enum [
    "intel"
    "amd"
    "nvidia"
  ];
  integrated = lib.filter (v: v != "nvidia") cfg.vendors;
in
{
  options.marchyo.graphics = {
    vendors = mkOption {
      type = types.listOf vendor;
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

        Every listed vendor's drivers, firmware and video-acceleration
        packages are installed. With more than one vendor, set `primary`
        to the GPU that drives the display. When empty, no vendor-specific
        drivers are installed (Mesa's generic stack still runs).

        Find your GPUs with: lspci | grep -E 'VGA|3D|Display'
      '';
    };

    primary = mkOption {
      type = types.nullOr vendor;
      default =
        if builtins.length cfg.vendors == 1 then
          builtins.head cfg.vendors
        else if cfg.prime.enable && builtins.length integrated == 1 then
          if cfg.prime.mode == "sync" then "nvidia" else builtins.head integrated
        else
          null;
      defaultText = lib.literalMD ''
        the only entry of `vendors`; on a PRIME laptop with one integrated
        GPU, `"nvidia"` in `sync` mode and the integrated GPU otherwise;
        else `null`
      '';
      example = "amd";
      description = ''
        The GPU that drives the display, one of `vendors`. Required when
        more than one vendor is listed.

        Only the primary GPU gets the global driver selection
        (`LIBVA_DRIVER_NAME`, `VDPAU_DRIVER`, and NVIDIA's GLX/GBM
        variables), and with several GPUs Hyprland renders on it first
        (`AQ_DRM_DEVICES`). Run a single app on another GPU with
        `nvidia-offload <command>` (PRIME offload) or `DRI_PRIME=1 <command>`
        (Mesa GPUs).
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
          `LIBVA_DRIVER_NAME` and `VDPAU_DRIVER` are set to "radeonsi" only when AMD
          is `primary`.
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
          Requires nvidia and an integrated GPU (intel or amd) in vendors.
          The integrated GPU PRIME pairs with is `primary` (in `sync` mode,
          where `primary` is nvidia, the only integrated GPU, or Intel when
          both are listed and `intelBusId` is set).
        '';
      };

      intelBusId = mkOption {
        type = types.str;
        default = "";
        example = "PCI:0:2:0";
        description = ''
          PCI bus ID of the Intel GPU. Used by PRIME, and to pick the exact
          device for Hyprland's GPU list when several GPUs are listed.
          Find with: lspci | grep -E 'VGA|3D' | grep Intel
          Format: PCI:bus:device:function (convert hex to decimal)
        '';
      };

      amdgpuBusId = mkOption {
        type = types.str;
        default = "";
        example = "PCI:6:0:0";
        description = ''
          PCI bus ID of the AMD GPU. Used by PRIME, and to pick the exact
          device for Hyprland's GPU list when several GPUs are listed.
          Find with: lspci | grep -E 'VGA|3D' | grep AMD
          Format: PCI:bus:device:function (convert hex to decimal)
        '';
      };

      nvidiaBusId = mkOption {
        type = types.str;
        default = "";
        example = "PCI:1:0:0";
        description = ''
          PCI bus ID of the NVIDIA GPU. Used by PRIME, and to pick the exact
          device for Hyprland's GPU list when several GPUs are listed.
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
            `primary` must be "nvidia".
          - "reverse-sync": iGPU for display, dGPU for compute.
        '';
      };
    };
  };
}

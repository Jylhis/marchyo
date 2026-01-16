# Graphics and GPU configuration module
# Supports Intel, AMD, NVIDIA, and hybrid graphics (PRIME)
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.marchyo.graphics;

  hasIntel = builtins.elem "intel" cfg.vendors;
  hasAmd = builtins.elem "amd" cfg.vendors;
  hasNvidia = builtins.elem "nvidia" cfg.vendors;
  isHybrid = cfg.prime.enable && (hasIntel || hasAmd) && hasNvidia;
  isX86 = pkgs.stdenv.hostPlatform.system == "x86_64-linux";

  # Backward compatibility: if vendors empty on x86, default to Intel behavior
  legacyIntel = cfg.vendors == [ ] && isX86;
in
{
  config = lib.mkMerge [
    # Base graphics configuration (always applied)
    {
      hardware.graphics = {
        enable = lib.mkDefault true;
        enable32Bit = lib.mkDefault isX86;
      };
    }

    # Intel GPU configuration
    (lib.mkIf (hasIntel || legacyIntel) {
      hardware.graphics.extraPackages = with pkgs; [
        intel-media-driver # iHD driver for modern Intel (Broadwell+)
        vpl-gpu-rt # oneVPL runtime for hardware video (Quick Sync)
        intel-compute-runtime # OpenCL support
      ];

      environment.sessionVariables = {
        LIBVA_DRIVER_NAME = lib.mkDefault "iHD";
      };
    })

    # AMD GPU configuration
    (lib.mkIf hasAmd {
      hardware.amdgpu = {
        initrd.enable = lib.mkDefault true;
        opencl.enable = lib.mkDefault true;
      };

      # ROCm for OpenCL compute (Mesa handles VA-API/Vulkan natively)
      hardware.graphics.extraPackages = with pkgs; [
        rocmPackages.clr.icd
      ];

      environment.sessionVariables = {
        LIBVA_DRIVER_NAME = lib.mkDefault "radeonsi";
        VDPAU_DRIVER = lib.mkDefault "radeonsi";
      };
    })

    # NVIDIA GPU configuration
    (lib.mkIf hasNvidia {
      # Use NVIDIA driver
      services.xserver.videoDrivers = [ "nvidia" ];

      hardware.nvidia = {
        modesetting.enable = true;
        open = lib.mkDefault cfg.nvidia.open;
        nvidiaSettings = lib.mkDefault true;
        powerManagement.enable = lib.mkDefault cfg.nvidia.powerManagement;
      };

      # nvidia-vaapi-driver for VA-API support under Wayland
      hardware.graphics.extraPackages = with pkgs; [
        nvidia-vaapi-driver
      ];

      environment.sessionVariables = {
        # Tell GLX to use NVIDIA
        __GLX_VENDOR_LIBRARY_NAME = lib.mkDefault "nvidia";
        # Use direct backend for nvidia-vaapi-driver (better performance)
        NVD_BACKEND = lib.mkDefault "direct";
        # GBM backend (needed for Wayland compositors)
        GBM_BACKEND = lib.mkDefault "nvidia-drm";
      };
    })

    # NVIDIA PRIME hybrid graphics configuration
    (lib.mkIf isHybrid {
      hardware.nvidia.prime = lib.mkMerge [
        # Bus IDs
        (lib.mkIf hasIntel {
          inherit (cfg.prime) intelBusId;
        })
        (lib.mkIf (hasAmd && !hasIntel) {
          inherit (cfg.prime) amdgpuBusId;
        })
        {
          inherit (cfg.prime) nvidiaBusId;
        }

        # Mode-specific configuration
        (lib.mkIf (cfg.prime.mode == "offload") {
          offload = {
            enable = true;
            enableOffloadCmd = true; # Provides `nvidia-offload` command
          };
        })

        (lib.mkIf (cfg.prime.mode == "sync") {
          sync.enable = true;
        })

        (lib.mkIf (cfg.prime.mode == "reverse-sync") {
          reverseSync.enable = true;
        })
      ];
    })

    # Assertions for valid configuration
    {
      assertions = [
        {
          assertion = cfg.prime.enable -> (hasNvidia && (hasIntel || hasAmd));
          message = "PRIME requires nvidia and either intel or amd in marchyo.graphics.vendors";
        }
        {
          assertion = cfg.prime.enable -> (cfg.prime.nvidiaBusId != "");
          message = "PRIME requires marchyo.graphics.prime.nvidiaBusId to be set";
        }
        {
          assertion = cfg.prime.enable && hasIntel -> (cfg.prime.intelBusId != "");
          message = "PRIME with Intel requires marchyo.graphics.prime.intelBusId to be set";
        }
        {
          assertion = cfg.prime.enable && hasAmd && !hasIntel -> (cfg.prime.amdgpuBusId != "");
          message = "PRIME with AMD requires marchyo.graphics.prime.amdgpuBusId to be set";
        }
      ];
    }
  ];
}

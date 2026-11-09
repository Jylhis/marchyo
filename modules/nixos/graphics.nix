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
  isTuring = cfg.nvidia.generation == "turing-or-newer";

  # Backward compatibility: empty vendors on x86 defaults to Intel behavior.
  legacyIntel = cfg.vendors == [ ] && isX86;

  hasAnyGpu = hasIntel || hasAmd || hasNvidia || legacyIntel;

  # On hybrid laptops in offload or reverse-sync mode the iGPU drives the
  # panel, and forcing NVIDIA's VA-API/GLX/GBM drivers globally breaks
  # Mesa clients such as Chromium (black video).
  nvidiaDrivesDisplay =
    hasNvidia && ((!hasIntel && !hasAmd) || (isHybrid && cfg.prime.mode == "sync"));
  nvidiaVaapi = nvidiaDrivesDisplay && isTuring;
  amdPrimary = hasAmd && !hasIntel && !nvidiaVaapi;

  mUsers = lib.attrNames (lib.filterAttrs (_name: user: user.enable) config.marchyo.users);

  nvidiaModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
  ];
in
{
  config = lib.mkMerge [
    {
      hardware.graphics = {
        enable = lib.mkDefault true;
        enable32Bit = lib.mkDefault isX86;
      };
    }

    # Vulkan userspace for any configured GPU vendor: the loader plus
    # diagnostic tools (vulkaninfo, vkcube). The ICDs come from Mesa
    # (Intel ANV / AMD RADV) or the NVIDIA driver; 32-bit driver support is
    # already handled by hardware.graphics.enable32Bit above.
    (lib.mkIf hasAnyGpu {
      environment.systemPackages = with pkgs; [
        vulkan-loader
        vulkan-tools
      ];
    })

    (lib.mkIf (hasIntel || legacyIntel) {
      hardware.graphics.extraPackages = with pkgs; [
        intel-media-driver
        vpl-gpu-rt
        intel-compute-runtime
      ];

      environment.sessionVariables = lib.mkIf (!nvidiaVaapi) {
        LIBVA_DRIVER_NAME = lib.mkDefault "iHD";
      };
    })

    (lib.mkIf hasAmd {
      hardware.amdgpu = {
        initrd.enable = lib.mkDefault true;
        opencl.enable = lib.mkDefault true;
        overdrive.enable = lib.mkDefault cfg.amd.overdrive.enable;
      };

      hardware.graphics.extraPackages = with pkgs; [
        rocmPackages.clr.icd
      ];

      environment.systemPackages = with pkgs; [
        rocmPackages.rocminfo
      ];
    })

    (lib.mkIf (hasAmd && cfg.amd.vaapi.enable) {
      environment.systemPackages = [ pkgs.libva-utils ];

      environment.sessionVariables = lib.mkIf amdPrimary {
        LIBVA_DRIVER_NAME = lib.mkDefault "radeonsi";
        VDPAU_DRIVER = lib.mkDefault "radeonsi";
      };
    })

    (lib.mkIf (hasAmd && cfg.amd.rocm.enable) {
      hardware.amdgpu.opencl.enable = true;

      environment.systemPackages = [ pkgs.rocmPackages.clr ];

      systemd.tmpfiles.rules = [
        "L+ /opt/rocm/hip - - - - ${pkgs.rocmPackages.clr}"
      ];

      environment.sessionVariables = lib.mkIf (cfg.amd.rocm.hsaOverrideGfxVersion != null) {
        HSA_OVERRIDE_GFX_VERSION = cfg.amd.rocm.hsaOverrideGfxVersion;
      };

      users.users = lib.genAttrs mUsers (_name: {
        extraGroups = [
          "render"
          "video"
        ];
      });
    })

    (lib.mkIf hasNvidia {
      services.xserver.videoDrivers = [ "nvidia" ];

      hardware.nvidia = {
        modesetting.enable = true;
        package = lib.mkDefault config.boot.kernelPackages.nvidiaPackages.${cfg.nvidia.package};
        open = lib.mkDefault cfg.nvidia.open;
        nvidiaSettings = lib.mkDefault true;
        powerManagement.enable = lib.mkDefault cfg.nvidia.powerManagement;
      };

      hardware.nvidia-container-toolkit.enable = lib.mkDefault cfg.nvidia.containerToolkit.enable;

      hardware.graphics.extraPackages = with pkgs; [
        nvidia-vaapi-driver
      ];

      environment.sessionVariables = lib.mkMerge [
        {
          NVD_BACKEND = lib.mkDefault (if isTuring then "direct" else "egl");
        }
        (lib.mkIf nvidiaDrivesDisplay {
          __GLX_VENDOR_LIBRARY_NAME = lib.mkDefault "nvidia";
          GBM_BACKEND = lib.mkDefault "nvidia-drm";
        })
        (lib.mkIf nvidiaVaapi {
          LIBVA_DRIVER_NAME = lib.mkDefault "nvidia";
        })
      ];

      # Early kernel module loading prevents race conditions with display manager.
      boot.initrd.kernelModules = nvidiaModules;
    })

    (lib.mkIf isHybrid {
      hardware.nvidia.prime = lib.mkMerge [
        (lib.mkIf hasIntel {
          inherit (cfg.prime) intelBusId;
        })
        (lib.mkIf (hasAmd && !hasIntel) {
          inherit (cfg.prime) amdgpuBusId;
        })
        {
          inherit (cfg.prime) nvidiaBusId;
        }

        (lib.mkIf (cfg.prime.mode == "offload") {
          offload = {
            # Normal priority, deliberately not lib.mkDefault: nixpkgs'
            # nvidia module already defines this option at mkDefault
            # (hardware/video/nvidia.nix), so a second mkDefault here would be
            # an equal-priority conflict rather than an override. The consumer
            # knob is marchyo.graphics.prime.mode.
            enable = true;
            enableOffloadCmd = true;
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

    (lib.mkIf (isHybrid && cfg.prime.integratedOnlySpecialisation) {
      specialisation.integrated-only.configuration = {
        system.nixos.tags = [ "integrated-only" ];
        marchyo.graphics = {
          vendors = lib.mkForce (lib.remove "nvidia" cfg.vendors);
          prime.enable = lib.mkForce false;
          prime.integratedOnlySpecialisation = lib.mkForce false;
          nvidia.containerToolkit.enable = lib.mkForce false;
        };
        boot.blacklistedKernelModules = nvidiaModules ++ [ "nouveau" ];
      };
    })

    {
      warnings = lib.optionals (legacyIntel && config.marchyo.desktop.enable) [
        "marchyo.graphics.vendors is empty on x86_64. This defaults to Intel behavior. Set vendors explicitly (e.g. [\"nvidia\"] or [\"amd\"])."
      ];

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
        {
          assertion = cfg.prime.integratedOnlySpecialisation -> cfg.prime.enable;
          message = "marchyo.graphics.prime.integratedOnlySpecialisation requires marchyo.graphics.prime.enable";
        }
        {
          assertion = hasNvidia && cfg.nvidia.open -> isTuring;
          message = ''marchyo.graphics.nvidia.open = true requires a Turing or newer GPU; set nvidia.open = false or nvidia.generation = "turing-or-newer"'';
        }
        {
          assertion = cfg.nvidia.containerToolkit.enable -> hasNvidia;
          message = ''marchyo.graphics.nvidia.containerToolkit.enable requires "nvidia" in marchyo.graphics.vendors'';
        }
        {
          assertion = cfg.amd.rocm.enable -> hasAmd;
          message = ''marchyo.graphics.amd.rocm.enable requires "amd" in marchyo.graphics.vendors'';
        }
      ];
    }
  ];
}

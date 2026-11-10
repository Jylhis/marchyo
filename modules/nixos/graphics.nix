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
  hasAnyGpu = cfg.vendors != [ ];
  multiGpu = builtins.length (lib.unique cfg.vendors) > 1;
  isHybrid = cfg.prime.enable && (hasIntel || hasAmd) && hasNvidia;
  isX86 = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  isTuring = cfg.nvidia.generation == "turing-or-newer";

  # The global driver selection follows the primary GPU only: one value per
  # variable, so a second GPU can never override (or conflict with) it.
  intelPrimary = cfg.primary == "intel";
  amdPrimary = cfg.primary == "amd";
  nvidiaPrimary = cfg.primary == "nvidia";
  # nvidia-vaapi-driver's direct backend needs a GSP (Turing or newer).
  nvidiaVaapi = nvidiaPrimary && isTuring;

  # The integrated GPU PRIME pairs with: the primary one, or (NVIDIA
  # primary, sync mode) the only one, Intel when both are listed and its bus
  # ID is set.
  primeIgpu =
    if cfg.primary == "intel" || cfg.primary == "amd" then
      cfg.primary
    else if hasIntel && (!hasAmd || cfg.prime.intelBusId != "") then
      "intel"
    else
      "amd";
  igpuBusId = if primeIgpu == "intel" then cfg.prime.intelBusId else cfg.prime.amdgpuBusId;

  # Stable per-vendor DRM node for Hyprland (/dev/dri/card<N> numbering
  # follows probe order). Matched by PCI address when the bus ID is set, else
  # by kernel driver. Aquamarine splits AQ_DRM_DEVICES on ':', so the
  # colon-laden /dev/dri/by-path names cannot be used directly.
  busIds = {
    intel = cfg.prime.intelBusId;
    amd = cfg.prime.amdgpuBusId;
    nvidia = cfg.prime.nvidiaBusId;
  };
  drivers = {
    intel = "i915|xe";
    amd = "amdgpu";
    nvidia = "nvidia";
  };
  # "PCI:<bus>[@<domain>]:<device>:<function>" (decimal) -> sysfs "dddd:bb:dd.f".
  pciAddress =
    busId:
    let
      m = builtins.match "PCI:([0-9]+)(@([0-9]+))?:([0-9]+):([0-9]+)" busId;
      hex = width: n: lib.toLower (lib.fixedWidthString width "0" (lib.toHexString (lib.toInt n)));
      domain = builtins.elemAt m 2;
    in
    if m == null then
      null
    else
      "${
        hex 4 (if domain == null then "0" else domain)
      }:${hex 2 (builtins.elemAt m 0)}:${hex 2 (builtins.elemAt m 3)}.${hex 1 (builtins.elemAt m 4)}";
  drmNode = v: "/dev/dri/marchyo-${v}";
  udevRule =
    v:
    let
      address = pciAddress busIds.${v};
      match = if address != null then ''KERNELS=="${address}"'' else ''DRIVERS=="${drivers.${v}}"'';
    in
    ''SUBSYSTEM=="drm", KERNEL=="card[0-9]*", ENV{DEVTYPE}=="drm_minor", ${match}, SYMLINK+="dri/marchyo-${v}"'';
  # Primary first: aquamarine renders on the first device and still drives
  # outputs wired to the others.
  drmOrder =
    lib.optional (cfg.primary != null) cfg.primary ++ lib.remove cfg.primary (lib.unique cfg.vendors);

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
      # Headless hosts without a listed GPU skip the graphics stack.
      hardware.graphics = {
        enable = lib.mkDefault (config.marchyo.desktop.enable || hasAnyGpu);
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

    (lib.mkIf hasIntel {
      hardware.graphics.extraPackages = with pkgs; [
        intel-media-driver
        vpl-gpu-rt
        intel-compute-runtime
      ];

      environment.sessionVariables = lib.mkIf intelPrimary {
        LIBVA_DRIVER_NAME = lib.mkDefault "iHD";
      };
    })

    (lib.mkIf hasAmd {
      hardware.amdgpu = {
        initrd.enable = lib.mkDefault true;
        opencl.enable = lib.mkDefault true;
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
        package =
          lib.mkDefault
            config.boot.kernelPackages.nvidiaPackages.${if isTuring then "stable" else "legacy_580"};
        open = lib.mkDefault isTuring;
        nvidiaSettings = lib.mkDefault true;
      };

      # GPU access for Podman and Docker containers through CDI.
      hardware.nvidia-container-toolkit.enable = lib.mkDefault config.marchyo.development.enable;

      hardware.graphics.extraPackages = with pkgs; [
        nvidia-vaapi-driver
      ];

      environment.sessionVariables = lib.mkMerge [
        {
          # Read only by nvidia-vaapi-driver, so harmless when NVIDIA is not
          # primary and right for apps run with nvidia-offload.
          NVD_BACKEND = lib.mkDefault (if isTuring then "direct" else "egl");
        }
        (lib.mkIf nvidiaPrimary {
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
        (if primeIgpu == "intel" then { intelBusId = igpuBusId; } else { amdgpuBusId = igpuBusId; })
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
          primary = lib.mkForce primeIgpu;
          prime.enable = lib.mkForce false;
          prime.integratedOnlySpecialisation = lib.mkForce false;
        };
        hardware.nvidia-container-toolkit.enable = lib.mkForce false;
        boot.blacklistedKernelModules = nvidiaModules ++ [ "nouveau" ];
      };
    })

    # Several GPUs: give each a stable node and have Hyprland render on the
    # primary one first.
    (lib.mkIf (multiGpu && cfg.primary != null) {
      services.udev.extraRules = lib.concatMapStringsSep "\n" udevRule drmOrder;

      environment.sessionVariables = lib.mkIf config.marchyo.desktop.enable {
        AQ_DRM_DEVICES = lib.mkDefault (lib.concatMapStringsSep ":" drmNode drmOrder);
      };
    })

    {
      assertions = [
        {
          assertion = multiGpu -> cfg.primary != null;
          message = "marchyo.graphics.vendors lists several GPUs (${lib.concatStringsSep ", " cfg.vendors}); set marchyo.graphics.primary to the one that drives the display";
        }
        {
          assertion = cfg.primary != null -> builtins.elem cfg.primary cfg.vendors;
          message = ''marchyo.graphics.primary = "${toString cfg.primary}" must be one of marchyo.graphics.vendors'';
        }
        {
          assertion = isHybrid && cfg.prime.mode == "sync" -> nvidiaPrimary;
          message = ''marchyo.graphics.prime.mode = "sync" renders everything on NVIDIA; set marchyo.graphics.primary = "nvidia"'';
        }
        {
          assertion = isHybrid && cfg.prime.mode != "sync" -> !nvidiaPrimary;
          message = ''marchyo.graphics.prime.mode = "${cfg.prime.mode}" drives the display from the integrated GPU; set marchyo.graphics.primary to "intel" or "amd"'';
        }
        {
          assertion = cfg.prime.enable -> (hasNvidia && (hasIntel || hasAmd));
          message = "PRIME requires nvidia and either intel or amd in marchyo.graphics.vendors";
        }
        {
          assertion = cfg.prime.enable -> (cfg.prime.nvidiaBusId != "");
          message = "PRIME requires marchyo.graphics.prime.nvidiaBusId to be set";
        }
        {
          assertion = isHybrid && primeIgpu == "intel" -> (cfg.prime.intelBusId != "");
          message = "PRIME with Intel requires marchyo.graphics.prime.intelBusId to be set";
        }
        {
          assertion = isHybrid && primeIgpu == "amd" -> (cfg.prime.amdgpuBusId != "");
          message = "PRIME with AMD requires marchyo.graphics.prime.amdgpuBusId to be set";
        }
        {
          assertion = lib.all (v: busIds.${v} == "" || pciAddress busIds.${v} != null) cfg.vendors;
          message = ''marchyo.graphics.prime bus IDs must look like "PCI:<bus>:<device>:<function>" (decimal), optionally "PCI:<bus>@<domain>:<device>:<function>"'';
        }
        {
          assertion = cfg.prime.integratedOnlySpecialisation -> cfg.prime.enable;
          message = "marchyo.graphics.prime.integratedOnlySpecialisation requires marchyo.graphics.prime.enable";
        }
        {
          assertion = hasNvidia && config.hardware.nvidia.open -> isTuring;
          message = ''hardware.nvidia.open = true requires a Turing or newer GPU; set hardware.nvidia.open = false or marchyo.graphics.nvidia.generation = "turing-or-newer"'';
        }
        {
          assertion = cfg.amd.rocm.enable -> hasAmd;
          message = ''marchyo.graphics.amd.rocm.enable requires "amd" in marchyo.graphics.vendors'';
        }
      ];
    }
  ];
}

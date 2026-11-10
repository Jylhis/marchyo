# Graphics: per-vendor drivers and environment, PRIME, multi-GPU primaries and
# the NVIDIA/AMD option surface. The single-vendor configurations are shared
# reference systems (nvidia, nvidia-tweaks, prime-offload, desktop-amd,
# amd-tweaks); the multi-GPU layouts, each a distinct topology, are variants.
{
  helpers,
  lib,
  pkgs,
  ...
}:
let
  inherit (helpers) minimalConfig withTestUser desktopWith;

  x86 = pkgs.stdenv.hostPlatform.isx86_64;

  env = c: c.environment.sessionVariables;
  noNvidiaDisplayEnv =
    c:
    !(env c ? __GLX_VENDOR_LIBRARY_NAME)
    && !(env c ? GBM_BACKEND)
    && (env c).LIBVA_DRIVER_NAME or "" != "nvidia";

  # The rendered Home Manager Hyprland env entries, as one string.
  hyprEnv =
    c:
    helpers.hyprEntriesText c.home-manager.users.testuser.wayland.windowManager.hyprland.settings.env;

  hybrid = mode: {
    vendors = [
      "intel"
      "nvidia"
    ];
    prime = {
      enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
      inherit mode;
    };
  };

  minimalWith = graphics: minimalConfig // { marchyo.graphics = graphics; };
in
{
  refs = {
    # minimalConfig + vendors = [ "nvidia" ].
    nvidia = {
      eval-graphics-nvidia-env =
        c:
        (env c).NVD_BACKEND == "direct"
        && (env c).LIBVA_DRIVER_NAME == "nvidia"
        && (env c).__GLX_VENDOR_LIBRARY_NAME == "nvidia"
        && c.hardware.nvidia.open
        && !c.hardware.nvidia-container-toolkit.enable;

      eval-graphics-nvidia = c: lib.elem "nvidia" c.services.xserver.videoDrivers;
    }
    // lib.optionalAttrs x86 {
      eval-graphics-nvidia-package-default =
        c: c.hardware.nvidia.package.version == c.boot.kernelPackages.nvidiaPackages.stable.version;
    };

    # withTestUser + development + nvidia, with the toolkit, open and power
    # management options moved off their defaults (refConfig below and in
    # removed-options.nix) and the beta driver package.
    nvidia-tweaks = {
      eval-graphics-nvidia-container-toolkit-opt-out = c: !c.hardware.nvidia-container-toolkit.enable;
    }
    // lib.optionalAttrs x86 {
      eval-graphics-nvidia-package =
        c: c.hardware.nvidia.package.version == c.boot.kernelPackages.nvidiaPackages.beta.version;
    };

    # minimalConfig + Intel/NVIDIA PRIME offload.
    prime-offload = {
      eval-graphics-prime-offload-env =
        c:
        noNvidiaDisplayEnv c
        && (env c).LIBVA_DRIVER_NAME == "iHD"
        && (env c).NVD_BACKEND == "direct"
        && c.hardware.nvidia.prime.offload.enable;

      eval-graphics-no-specialisation-by-default = c: c.specialisation == { };

      eval-graphics-prime-offload = c: c.hardware.nvidia.prime.offload.enable;
    };

    # desktop + vendors = [ "amd" ].
    desktop-amd = {
      eval-graphics-amd-vaapi =
        c: (env c).LIBVA_DRIVER_NAME == "radeonsi" && (env c).VDPAU_DRIVER == "radeonsi";

      eval-graphics-amd =
        c:
        c.marchyo.graphics.primary == "amd"
        && (env c).LIBVA_DRIVER_NAME == "radeonsi"
        && !(env c ? AQ_DRM_DEVICES)
        && !(lib.elem "intel-media-driver" (map lib.getName c.hardware.graphics.extraPackages));
    }
    # Forcing package names touches ROCm attrs; keep this off the non-x86 CI legs.
    // lib.optionalAttrs x86 {
      # Vulkan userspace (loader + tools) ships for any configured vendor; AMD
      # additionally gets rocminfo.
      eval-graphics-amd-tooling =
        c:
        let
          names = map lib.getName c.environment.systemPackages;
        in
        lib.elem "vulkan-loader" names && lib.elem "vulkan-tools" names && lib.elem "rocminfo" names;
    };

    # withTestUser + AMD with VA-API off, overdrive on (hardware.amdgpu.overdrive
    # here, the renamed marchyo option in removed-options.nix) and ROCm.
    amd-tweaks = {
      eval-graphics-amd-vaapi-off = c: !(env c ? LIBVA_DRIVER_NAME) && !(env c ? VDPAU_DRIVER);

      eval-graphics-amd-overdrive =
        c:
        c.hardware.amdgpu.overdrive.enable
        && lib.any (lib.hasPrefix "amdgpu.ppfeaturemask=") c.boot.kernelParams;
    }
    // lib.optionalAttrs x86 {
      eval-graphics-rocm =
        c:
        (env c).HSA_OVERRIDE_GFX_VERSION == "10.3.0"
        && lib.any (lib.hasPrefix "L+ /opt/rocm/hip ") c.systemd.tmpfiles.rules
        && lib.elem "clr" (map lib.getName c.environment.systemPackages)
        && lib.all (g: lib.elem g c.users.users.testuser.extraGroups) [
          "render"
          "video"
        ];
    };

    # A single GPU needs no primary, no DRM list and no udev nodes
    # (desktop-tweaks: vendors = [ "intel" ]).
    desktop-tweaks.eval-graphics-intel =
      c:
      c.marchyo.graphics.primary == "intel"
      && (env c).LIBVA_DRIVER_NAME == "iHD"
      && !(env c ? AQ_DRM_DEVICES)
      && !(lib.hasInfix "marchyo-intel" c.services.udev.extraRules)
      && lib.elem "intel-media-driver" (map lib.getName c.hardware.graphics.extraPackages);

    # Empty vendors on a desktop: the generic graphics stack, no vendor drivers
    # and no driver guess.
    desktop.eval-graphics-no-vendors-desktop =
      c:
      c.hardware.graphics.enable
      && c.marchyo.graphics.primary == null
      && !(env c ? LIBVA_DRIVER_NAME)
      && !(env c ? VDPAU_DRIVER)
      && !(lib.elem "intel-media-driver" (map lib.getName c.hardware.graphics.extraPackages))
      && !(lib.any (lib.hasInfix "marchyo.graphics.vendors") c.warnings);

    # Headless with no GPU listed: no graphics stack at all.
    headless.eval-graphics-headless = c: !c.hardware.graphics.enable && !(env c ? LIBVA_DRIVER_NAME);
  };

  refConfig = {
    nvidia-tweaks = {
      imports = [
        (
          { config, ... }:
          lib.mkIf x86 { hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.beta; }
        )
      ];
      marchyo.development.enable = true;
      marchyo.graphics.vendors = [ "nvidia" ];
      hardware.nvidia-container-toolkit.enable = false;
    };
    amd-tweaks = {
      marchyo.graphics = {
        vendors = [ "amd" ];
        amd.vaapi.enable = false;
        amd.rocm = {
          enable = true;
          hsaOverrideGfxVersion = "10.3.0";
        };
      };
      hardware.amdgpu.overdrive.enable = true;
    };
    desktop-tweaks.marchyo.graphics.vendors = [ "intel" ];
  };

  variants = {
    nvidia-pre-turing = {
      config = minimalWith {
        vendors = [ "nvidia" ];
        nvidia.generation = "pre-turing";
      };
      predicates = {
        eval-graphics-nvidia-pre-turing =
          c:
          (env c).NVD_BACKEND == "egl"
          && (env c).__GLX_VENDOR_LIBRARY_NAME == "nvidia"
          && !(env c ? LIBVA_DRIVER_NAME)
          && !c.hardware.nvidia.open;
      }
      // lib.optionalAttrs x86 {
        eval-graphics-nvidia-package-pre-turing =
          c: c.hardware.nvidia.package.version == c.boot.kernelPackages.nvidiaPackages.legacy_580.version;
      };
    };

    prime-offload-specialisation = {
      config = withTestUser {
        marchyo.development.enable = true;
        marchyo.graphics = lib.recursiveUpdate (hybrid "offload") {
          prime.integratedOnlySpecialisation = true;
        };
      };
      predicates = {
        # development + an NVIDIA GPU turns the container toolkit on.
        eval-graphics-nvidia-container-toolkit = c: c.hardware.nvidia-container-toolkit.enable;

        eval-graphics-integrated-only-specialisation =
          c:
          let
            child = c.specialisation.integrated-only.configuration;
          in
          c.hardware.nvidia-container-toolkit.enable
          && lib.all (a: a.assertion) child.assertions
          && child.specialisation == { }
          && !(lib.elem "nvidia" child.services.xserver.videoDrivers)
          && !child.hardware.nvidia-container-toolkit.enable
          && !child.hardware.nvidia.prime.offload.enable
          && lib.all (m: lib.elem m child.boot.blacklistedKernelModules) [
            "nvidia"
            "nvidia_drm"
            "nouveau"
          ]
          && !(lib.elem "nvidia" child.boot.initrd.kernelModules)
          && !(env child ? NVD_BACKEND)
          && noNvidiaDisplayEnv child
          && (env child).LIBVA_DRIVER_NAME == "iHD";
      };
    };

    prime-reverse-sync = {
      config = minimalWith (hybrid "reverse-sync");
      predicates.eval-graphics-prime-reverse-sync-env =
        c: noNvidiaDisplayEnv c && c.hardware.nvidia.prime.reverseSync.enable;
    };

    prime-sync-intel = {
      config = minimalWith (hybrid "sync");
      predicates.eval-graphics-prime-sync-env =
        c:
        (env c).LIBVA_DRIVER_NAME == "nvidia"
        && (env c).__GLX_VENDOR_LIBRARY_NAME == "nvidia"
        && c.hardware.nvidia.prime.sync.enable;
    };

    prime-sync-amd = {
      config = minimalWith {
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
      predicates.eval-graphics-prime-sync = c: c.hardware.nvidia.prime.sync.enable;
    };

    # Intel + AMD, AMD drives the display: both driver sets install, only the
    # primary picks the VA-API/VDPAU driver, and Hyprland gets stable nodes with
    # the primary first.
    intel-amd-primary-amd = {
      config = desktopWith {
        marchyo.graphics = {
          vendors = [
            "intel"
            "amd"
          ];
          primary = "amd";
        };
      };
      predicates.eval-graphics-intel-amd-primary-amd =
        c:
        (env c).LIBVA_DRIVER_NAME == "radeonsi"
        && (env c).VDPAU_DRIVER == "radeonsi"
        && lib.elem "intel-media-driver" (map lib.getName c.hardware.graphics.extraPackages)
        && c.hardware.amdgpu.initrd.enable
        && (env c).AQ_DRM_DEVICES == "/dev/dri/marchyo-amd:/dev/dri/marchyo-intel"
        && lib.hasInfix ''DRIVERS=="amdgpu", SYMLINK+="dri/marchyo-amd"'' c.services.udev.extraRules
        && lib.hasInfix ''DRIVERS=="i915|xe", SYMLINK+="dri/marchyo-intel"'' c.services.udev.extraRules;
    };

    # Intel + AMD, Intel primary, with a PCI address in the domain@bus form.
    intel-amd-primary-intel = {
      config = desktopWith {
        marchyo.graphics = {
          vendors = [
            "intel"
            "amd"
          ];
          primary = "intel";
          prime.intelBusId = "PCI:10@1:31:3";
        };
      };
      predicates = {
        eval-graphics-intel-amd-primary-intel =
          c:
          (env c).LIBVA_DRIVER_NAME == "iHD"
          && !(env c ? VDPAU_DRIVER)
          && (env c).AQ_DRM_DEVICES == "/dev/dri/marchyo-intel:/dev/dri/marchyo-amd";

        eval-graphics-pci-address =
          c:
          lib.hasInfix ''KERNELS=="0001:0a:1f.3", SYMLINK+="dri/marchyo-intel"'' c.services.udev.extraRules;
      };
    };

    # AMD + NVIDIA offload: AMD is primary by default, PRIME pairs with its bus
    # ID, nothing NVIDIA-specific or offload-specific is exported globally, and
    # the DRM nodes match the exact PCI devices.
    amd-nvidia-offload = {
      config = desktopWith {
        marchyo.graphics = {
          vendors = [
            "amd"
            "nvidia"
          ];
          prime = {
            enable = true;
            amdgpuBusId = "PCI:6:0:0";
            nvidiaBusId = "PCI:1:0:0";
            mode = "offload";
          };
        };
      };
      predicates.eval-graphics-amd-nvidia-offload =
        c:
        let
          hmEnv = hyprEnv c;
        in
        c.marchyo.graphics.primary == "amd"
        && c.hardware.nvidia.prime.offload.enable
        && c.hardware.nvidia.prime.amdgpuBusId == "PCI:6:0:0"
        && c.hardware.nvidia.prime.intelBusId == ""
        && noNvidiaDisplayEnv c
        && (env c).LIBVA_DRIVER_NAME == "radeonsi"
        && !(env c ? __NV_PRIME_RENDER_OFFLOAD)
        && (env c).AQ_DRM_DEVICES == "/dev/dri/marchyo-amd:/dev/dri/marchyo-nvidia"
        && lib.hasInfix ''KERNELS=="0000:06:00.0", SYMLINK+="dri/marchyo-amd"'' c.services.udev.extraRules
        && lib.hasInfix ''KERNELS=="0000:01:00.0", SYMLINK+="dri/marchyo-nvidia"'' c.services.udev.extraRules
        && !(lib.hasInfix "LIBVA_DRIVER_NAME" hmEnv)
        && !(lib.hasInfix "__NV_PRIME_RENDER_OFFLOAD" hmEnv)
        && !(lib.hasInfix "__GLX_VENDOR_LIBRARY_NAME" hmEnv);
    };

    # Intel + AMD + NVIDIA: the AMD iGPU drives the display, so PRIME pairs
    # with AMD (not Intel) while every vendor's drivers still install.
    intel-amd-nvidia = {
      config = desktopWith {
        marchyo.graphics = {
          vendors = [
            "intel"
            "amd"
            "nvidia"
          ];
          primary = "amd";
          prime = {
            enable = true;
            amdgpuBusId = "PCI:6:0:0";
            nvidiaBusId = "PCI:1:0:0";
          };
        };
      };
      predicates.eval-graphics-intel-amd-nvidia =
        c:
        c.hardware.nvidia.prime.amdgpuBusId == "PCI:6:0:0"
        && c.hardware.nvidia.prime.intelBusId == ""
        && lib.elem "intel-media-driver" (map lib.getName c.hardware.graphics.extraPackages)
        && lib.elem "nvidia" c.services.xserver.videoDrivers
        && (env c).LIBVA_DRIVER_NAME == "radeonsi"
        && noNvidiaDisplayEnv c
        && (env c).AQ_DRM_DEVICES == "/dev/dri/marchyo-amd:/dev/dri/marchyo-intel:/dev/dri/marchyo-nvidia";
    };
  };

  failing = {
    eval-graphics-nvidia-open-pre-turing-fails = {
      on = "misconfigured-minimal";
      expect = "requires a Turing or newer GPU";
    };
    eval-graphics-specialisation-without-prime-fails = {
      on = "misconfigured-minimal";
      expect = "requires marchyo.graphics.prime.enable";
    };
    eval-graphics-bad-bus-id = {
      on = "misconfigured-minimal-2";
      expect = "bus IDs must look like";
    };
    eval-graphics-rocm-without-amd-fails = {
      on = "misconfigured-minimal-2";
      expect = "amd.rocm.enable requires \"amd\"";
    };
    # Two vendors and no primary (misconfigured).
    eval-graphics-multi-vendor-needs-primary = {
      on = "misconfigured";
      expect = "set marchyo.graphics.primary";
    };
    # A primary that is not a listed vendor (misconfigured-2).
    eval-graphics-primary-not-listed = {
      on = "misconfigured-2";
      expect = "must be one of marchyo.graphics.vendors";
    };
    # PRIME sync with the iGPU as primary (misconfigured-3).
    eval-graphics-prime-sync-needs-nvidia-primary = {
      on = "misconfigured-3";
      expect = "set marchyo.graphics.primary = \"nvidia\"";
    };
  };

  failingConfig = {
    # Pre-Turing with the open module, and the integrated-only specialisation
    # without PRIME: two independent assertions.
    misconfigured-minimal = {
      marchyo.graphics = {
        vendors = [ "nvidia" ];
        nvidia.generation = "pre-turing";
        prime.integratedOnlySpecialisation = true;
      };
      hardware.nvidia.open = true;
    };
    # A malformed bus ID and ROCm without an AMD GPU: likewise.
    misconfigured-minimal-2.marchyo.graphics = {
      vendors = [ "intel" ];
      prime.intelBusId = "0000:00:02.0";
      amd.rocm.enable = true;
    };
    misconfigured.marchyo.graphics.vendors = [
      "intel"
      "amd"
    ];
    misconfigured-2.marchyo.graphics = {
      vendors = [ "amd" ];
      primary = "intel";
    };
    misconfigured-3.marchyo.graphics = (hybrid "sync") // {
      primary = "intel";
    };
  };
}

{
  helpers,
  lib,
  pkgs,
  ...
}:
let
  inherit (helpers)
    testNixOS
    testNixOSCheck
    testNixOSFails
    minimalConfig
    withTestUser
    ;

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
in
{
  eval-graphics-nvidia-env = testNixOSCheck "graphics-nvidia-env" (
    c:
    (env c).NVD_BACKEND == "direct"
    && (env c).LIBVA_DRIVER_NAME == "nvidia"
    && (env c).__GLX_VENDOR_LIBRARY_NAME == "nvidia"
    && c.hardware.nvidia.open
    && !c.hardware.nvidia-container-toolkit.enable
  ) (minimalConfig // { marchyo.graphics.vendors = [ "nvidia" ]; });

  eval-graphics-nvidia-pre-turing =
    testNixOSCheck "graphics-nvidia-pre-turing"
      (
        c:
        (env c).NVD_BACKEND == "egl"
        && (env c).__GLX_VENDOR_LIBRARY_NAME == "nvidia"
        && !(env c ? LIBVA_DRIVER_NAME)
        && !c.hardware.nvidia.open
      )
      (
        minimalConfig
        // {
          marchyo.graphics = {
            vendors = [ "nvidia" ];
            nvidia.generation = "pre-turing";
          };
        }
      );

  eval-graphics-nvidia-open-pre-turing-fails =
    testNixOSFails "graphics-nvidia-open-pre-turing" "requires a Turing or newer GPU"
      (
        minimalConfig
        // {
          marchyo.graphics = {
            vendors = [ "nvidia" ];
            nvidia.generation = "pre-turing";
          };
          hardware.nvidia.open = true;
        }
      );

  eval-graphics-prime-offload-env = testNixOSCheck "graphics-prime-offload-env" (
    c:
    noNvidiaDisplayEnv c
    && (env c).LIBVA_DRIVER_NAME == "iHD"
    && (env c).NVD_BACKEND == "direct"
    && c.hardware.nvidia.prime.offload.enable
  ) (minimalConfig // { marchyo.graphics = hybrid "offload"; });

  eval-graphics-prime-reverse-sync-env = testNixOSCheck "graphics-prime-reverse-sync-env" (
    c: noNvidiaDisplayEnv c && c.hardware.nvidia.prime.reverseSync.enable
  ) (minimalConfig // { marchyo.graphics = hybrid "reverse-sync"; });

  eval-graphics-prime-sync-env = testNixOSCheck "graphics-prime-sync-env" (
    c:
    (env c).LIBVA_DRIVER_NAME == "nvidia"
    && (env c).__GLX_VENDOR_LIBRARY_NAME == "nvidia"
    && c.hardware.nvidia.prime.sync.enable
  ) (minimalConfig // { marchyo.graphics = hybrid "sync"; });

  eval-graphics-nvidia-container-toolkit =
    testNixOSCheck "graphics-nvidia-container-toolkit" (c: c.hardware.nvidia-container-toolkit.enable)
      (withTestUser {
        marchyo.development.enable = true;
        marchyo.graphics.vendors = [ "nvidia" ];
      });

  eval-graphics-nvidia-container-toolkit-opt-out =
    testNixOSCheck "graphics-nvidia-container-toolkit-opt-out"
      (c: !c.hardware.nvidia-container-toolkit.enable)
      (withTestUser {
        marchyo.development.enable = true;
        marchyo.graphics.vendors = [ "nvidia" ];
        hardware.nvidia-container-toolkit.enable = false;
      });

  eval-graphics-integrated-only-specialisation =
    testNixOSCheck "graphics-integrated-only-specialisation"
      (
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
        && (env child).LIBVA_DRIVER_NAME == "iHD"
      )
      (withTestUser {
        marchyo.development.enable = true;
        marchyo.graphics = lib.recursiveUpdate (hybrid "offload") {
          prime.integratedOnlySpecialisation = true;
        };
      });

  eval-graphics-no-specialisation-by-default =
    testNixOSCheck "graphics-no-specialisation-by-default" (c: c.specialisation == { })
      (minimalConfig // { marchyo.graphics = hybrid "offload"; });

  eval-graphics-specialisation-without-prime-fails =
    testNixOSFails "graphics-specialisation-without-prime" "requires marchyo.graphics.prime.enable"
      (
        minimalConfig
        // {
          marchyo.graphics = {
            vendors = [ "nvidia" ];
            prime.integratedOnlySpecialisation = true;
          };
        }
      );

  eval-graphics-amd-vaapi = testNixOSCheck "graphics-amd-vaapi" (
    c: (env c).LIBVA_DRIVER_NAME == "radeonsi" && (env c).VDPAU_DRIVER == "radeonsi"
  ) (minimalConfig // { marchyo.graphics.vendors = [ "amd" ]; });

  eval-graphics-amd-vaapi-off =
    testNixOSCheck "graphics-amd-vaapi-off" (c: !(env c ? LIBVA_DRIVER_NAME) && !(env c ? VDPAU_DRIVER))
      (
        minimalConfig
        // {
          marchyo.graphics = {
            vendors = [ "amd" ];
            amd.vaapi.enable = false;
          };
        }
      );

  # Intel + AMD, AMD drives the display: both driver sets install, only the
  # primary picks the VA-API/VDPAU driver, and Hyprland gets stable nodes with
  # the primary first.
  eval-graphics-intel-amd-primary-amd =
    testNixOSCheck "graphics-intel-amd-primary-amd"
      (
        c:
        (env c).LIBVA_DRIVER_NAME == "radeonsi"
        && (env c).VDPAU_DRIVER == "radeonsi"
        && lib.elem "intel-media-driver" (map lib.getName c.hardware.graphics.extraPackages)
        && c.hardware.amdgpu.initrd.enable
        && (env c).AQ_DRM_DEVICES == "/dev/dri/marchyo-amd:/dev/dri/marchyo-intel"
        && lib.hasInfix ''DRIVERS=="amdgpu", SYMLINK+="dri/marchyo-amd"'' c.services.udev.extraRules
        && lib.hasInfix ''DRIVERS=="i915|xe", SYMLINK+="dri/marchyo-intel"'' c.services.udev.extraRules
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.graphics = {
          vendors = [
            "intel"
            "amd"
          ];
          primary = "amd";
        };
      });

  eval-graphics-intel-amd-primary-intel =
    testNixOSCheck "graphics-intel-amd-primary-intel"
      (
        c:
        (env c).LIBVA_DRIVER_NAME == "iHD"
        && !(env c ? VDPAU_DRIVER)
        && (env c).AQ_DRM_DEVICES == "/dev/dri/marchyo-intel:/dev/dri/marchyo-amd"
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.graphics = {
          vendors = [
            "intel"
            "amd"
          ];
          primary = "intel";
        };
      });

  eval-graphics-multi-vendor-needs-primary =
    testNixOSFails "graphics-multi-vendor-needs-primary" "set marchyo.graphics.primary"
      (
        minimalConfig
        // {
          marchyo.graphics.vendors = [
            "intel"
            "amd"
          ];
        }
      );

  eval-graphics-primary-not-listed =
    testNixOSFails "graphics-primary-not-listed" "must be one of marchyo.graphics.vendors"
      (
        minimalConfig
        // {
          marchyo.graphics = {
            vendors = [ "amd" ];
            primary = "intel";
          };
        }
      );

  eval-graphics-prime-sync-needs-nvidia-primary =
    testNixOSFails "graphics-prime-sync-needs-nvidia-primary"
      "set marchyo.graphics.primary = \"nvidia\""
      (
        minimalConfig
        // {
          marchyo.graphics = (hybrid "sync") // {
            primary = "intel";
          };
        }
      );

  # AMD + NVIDIA offload: AMD is primary by default, PRIME pairs with its bus
  # ID, nothing NVIDIA-specific or offload-specific is exported globally, and
  # the DRM nodes match the exact PCI devices.
  eval-graphics-amd-nvidia-offload =
    testNixOSCheck "graphics-amd-nvidia-offload"
      (
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
        && !(lib.hasInfix "__GLX_VENDOR_LIBRARY_NAME" hmEnv)
      )
      (withTestUser {
        marchyo.desktop.enable = true;
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
      });

  # Intel + AMD + NVIDIA: the AMD iGPU drives the display, so PRIME pairs
  # with AMD (not Intel) while every vendor's drivers still install.
  eval-graphics-intel-amd-nvidia =
    testNixOSCheck "graphics-intel-amd-nvidia"
      (
        c:
        c.hardware.nvidia.prime.amdgpuBusId == "PCI:6:0:0"
        && c.hardware.nvidia.prime.intelBusId == ""
        && lib.elem "intel-media-driver" (map lib.getName c.hardware.graphics.extraPackages)
        && lib.elem "nvidia" c.services.xserver.videoDrivers
        && (env c).LIBVA_DRIVER_NAME == "radeonsi"
        && noNvidiaDisplayEnv c
        && (env c).AQ_DRM_DEVICES == "/dev/dri/marchyo-amd:/dev/dri/marchyo-intel:/dev/dri/marchyo-nvidia"
      )
      (withTestUser {
        marchyo.desktop.enable = true;
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
      });

  eval-graphics-pci-address =
    testNixOSCheck "graphics-pci-address"
      (
        c: lib.hasInfix ''KERNELS=="0001:0a:1f.3", SYMLINK+="dri/marchyo-intel"'' c.services.udev.extraRules
      )
      (withTestUser {
        marchyo.graphics = {
          vendors = [
            "intel"
            "amd"
          ];
          primary = "intel";
          prime.intelBusId = "PCI:10@1:31:3";
        };
      });

  eval-graphics-bad-bus-id = testNixOSFails "graphics-bad-bus-id" "bus IDs must look like" (
    minimalConfig
    // {
      marchyo.graphics = {
        vendors = [ "intel" ];
        prime.intelBusId = "0000:00:02.0";
      };
    }
  );

  eval-graphics-amd-overdrive =
    testNixOSCheck "graphics-amd-overdrive"
      (
        c:
        c.hardware.amdgpu.overdrive.enable
        && lib.any (lib.hasPrefix "amdgpu.ppfeaturemask=") c.boot.kernelParams
      )
      (
        minimalConfig
        // {
          marchyo.graphics.vendors = [ "amd" ];
          hardware.amdgpu.overdrive.enable = true;
        }
      );

  eval-graphics-rocm-without-amd-fails =
    testNixOSFails "graphics-rocm-without-amd" "amd.rocm.enable requires \"amd\""
      (
        minimalConfig
        // {
          marchyo.graphics = {
            vendors = [ "intel" ];
            amd.rocm.enable = true;
          };
        }
      );

  # A single GPU needs no primary, no DRM list and no udev nodes.
  eval-graphics-intel =
    testNixOSCheck "graphics-intel"
      (
        c:
        c.marchyo.graphics.primary == "intel"
        && (env c).LIBVA_DRIVER_NAME == "iHD"
        && !(env c ? AQ_DRM_DEVICES)
        && !(lib.hasInfix "marchyo-intel" c.services.udev.extraRules)
        && lib.elem "intel-media-driver" (map lib.getName c.hardware.graphics.extraPackages)
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.graphics.vendors = [ "intel" ];
      });

  eval-graphics-amd =
    testNixOSCheck "graphics-amd"
      (
        c:
        c.marchyo.graphics.primary == "amd"
        && (env c).LIBVA_DRIVER_NAME == "radeonsi"
        && !(env c ? AQ_DRM_DEVICES)
        && !(lib.elem "intel-media-driver" (map lib.getName c.hardware.graphics.extraPackages))
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.graphics.vendors = [ "amd" ];
      });

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

  # Empty vendors on a desktop: the generic graphics stack, no vendor drivers
  # and no driver guess.
  eval-graphics-no-vendors-desktop =
    testNixOSCheck "graphics-no-vendors-desktop"
      (
        c:
        c.hardware.graphics.enable
        && c.marchyo.graphics.primary == null
        && !(env c ? LIBVA_DRIVER_NAME)
        && !(env c ? VDPAU_DRIVER)
        && !(lib.elem "intel-media-driver" (map lib.getName c.hardware.graphics.extraPackages))
        && !(lib.any (lib.hasInfix "marchyo.graphics.vendors") c.warnings)
      )
      (withTestUser {
        marchyo.desktop.enable = true;
      });

  # Headless with no GPU listed: no graphics stack at all.
  eval-graphics-headless = testNixOSCheck "graphics-headless" (
    c: !c.hardware.graphics.enable && !(env c ? LIBVA_DRIVER_NAME)
  ) (withTestUser { });
}
# Forcing package names touches ROCm attrs; keep this off the non-x86 CI legs.
// lib.optionalAttrs pkgs.stdenv.hostPlatform.isx86_64 {
  # Vulkan userspace (loader + tools) ships for any configured vendor; AMD
  # additionally gets rocminfo. testNixOS never forces systemPackages, so
  # assert on the resolved package names.
  eval-graphics-amd-tooling = testNixOSCheck "graphics-amd-tooling" (
    c:
    let
      names = map lib.getName c.environment.systemPackages;
    in
    lib.elem "vulkan-loader" names && lib.elem "vulkan-tools" names && lib.elem "rocminfo" names
  ) (minimalConfig // { marchyo.graphics.vendors = [ "amd" ]; });

  eval-graphics-rocm =
    testNixOSCheck "graphics-rocm"
      (
        c:
        (env c).HSA_OVERRIDE_GFX_VERSION == "10.3.0"
        && lib.any (lib.hasPrefix "L+ /opt/rocm/hip ") c.systemd.tmpfiles.rules
        && lib.elem "clr" (map lib.getName c.environment.systemPackages)
        && lib.all (g: lib.elem g c.users.users.testuser.extraGroups) [
          "render"
          "video"
        ]
      )
      (withTestUser {
        marchyo.graphics = {
          vendors = [ "amd" ];
          amd.rocm = {
            enable = true;
            hsaOverrideGfxVersion = "10.3.0";
          };
        };
      });

  eval-graphics-nvidia-package =
    testNixOSCheck "graphics-nvidia-package"
      (c: c.hardware.nvidia.package.version == c.boot.kernelPackages.nvidiaPackages.beta.version)
      (
        minimalConfig
        // {
          marchyo.graphics.vendors = [ "nvidia" ];
          imports = [
            (
              { config, ... }:
              {
                hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.beta;
              }
            )
          ];
        }
      );

  eval-graphics-nvidia-package-default = testNixOSCheck "graphics-nvidia-package-default" (
    c: c.hardware.nvidia.package.version == c.boot.kernelPackages.nvidiaPackages.stable.version
  ) (minimalConfig // { marchyo.graphics.vendors = [ "nvidia" ]; });

  eval-graphics-nvidia-package-pre-turing =
    testNixOSCheck "graphics-nvidia-package-pre-turing"
      (c: c.hardware.nvidia.package.version == c.boot.kernelPackages.nvidiaPackages.legacy_580.version)
      (
        minimalConfig
        // {
          marchyo.graphics = {
            vendors = [ "nvidia" ];
            nvidia.generation = "pre-turing";
          };
        }
      );
}

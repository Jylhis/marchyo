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
            nvidia = {
              generation = "pre-turing";
              open = true;
            };
          };
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
        marchyo.graphics = {
          vendors = [ "nvidia" ];
          nvidia.containerToolkit.enable = false;
        };
      });

  eval-graphics-container-toolkit-without-nvidia-fails =
    testNixOSFails "graphics-container-toolkit-without-nvidia" "requires \"nvidia\""
      (
        minimalConfig
        // {
          marchyo.graphics = {
            vendors = [ "intel" ];
            nvidia.containerToolkit.enable = true;
          };
        }
      );

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

  eval-graphics-intel-amd-vaapi =
    testNixOSCheck "graphics-intel-amd-vaapi" (c: (env c).LIBVA_DRIVER_NAME == "iHD")
      (
        minimalConfig
        // {
          marchyo.graphics.vendors = [
            "intel"
            "amd"
          ];
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
          marchyo.graphics = {
            vendors = [ "amd" ];
            amd.overdrive.enable = true;
          };
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
          marchyo.graphics = {
            vendors = [ "nvidia" ];
            nvidia.package = "beta";
          };
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

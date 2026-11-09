# Camera access at login and the Elgato Cam Link 4K relay.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo;
  mUsers = lib.filterAttrs (_name: user: user.enable) cfg.users;

  waitForCameraAccess = pkgs.writeShellApplication {
    name = "marchyo-wait-camera-access";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      # Media devices the seat hands to the session (uaccess); the ACL arrives
      # moments after the user manager starts WirePlumber.
      devices=()
      for device in /dev/media*; do
        [ -e "$device" ] && [ ! -d "$device" ] || continue
        tags=$(udevadm info --query=property --property=CURRENT_TAGS --value "$device" 2>/dev/null || true)
        case "$tags" in *:uaccess:*) devices+=("$device") ;; esac
      done

      for _ in $(seq 50); do
        waiting=0
        for device in "''${devices[@]}"; do
          if [ ! -r "$device" ] || [ ! -w "$device" ]; then waiting=1; fi
        done
        [ "$waiting" = 0 ] && break
        sleep 0.1
      done
    '';
  };

  # Sorted after 70-uaccess adds the tag and before 73-seat-late applies the ACL.
  camlinkRules = pkgs.writeTextDir "lib/udev/rules.d/71-marchyo-camlink4k.rules" ''
    SUBSYSTEM=="video4linux", ENV{ID_VENDOR_ID}=="0fd9", ENV{ID_MODEL}=="Cam_Link_4K", \
      ENV{ID_V4L_CAPABILITIES}==":capture:", TAG-="uaccess", OWNER="root", GROUP="root", \
      MODE="0600", SYMLINK+="camlink4k", TAG+="systemd", ENV{SYSTEMD_ALIAS}="/dev/camlink4k", \
      ENV{SYSTEMD_WANTS}="v4l2-relayd-camlink.service"
  '';
in
{
  config = lib.mkMerge [
    (lib.mkIf cfg.hardware.camera.waitForAccess {
      systemd.user.services.wireplumber.serviceConfig.ExecStartPre = [
        "-${waitForCameraAccess}/bin/marchyo-wait-camera-access"
      ];
    })

    (lib.mkIf cfg.hardware.camlink.enable {
      services.v4l2-relayd.instances.camlink = {
        enable = true;
        cardLabel = "Cam Link 4K";
        input = {
          pipeline = "v4l2src device=/dev/camlink4k ! videoconvert ! videoscale ! videorate";
          format = "NV12";
          width = 1280;
          height = 720;
          framerate = 30;
        };
        output.format = "YUY2";
      };

      services.udev.packages = [ camlinkRules ];

      # The relay follows the device: udev starts it on plug-in and systemd
      # stops it when /dev/camlink4k goes away.
      systemd.services.v4l2-relayd-camlink = {
        wantedBy = lib.mkForce [ ];
        bindsTo = [ "dev-camlink4k.device" ];
        after = [ "dev-camlink4k.device" ];
      };

      users.users = lib.mapAttrs (_name: _user: { extraGroups = [ "video" ]; }) mUsers;
    })
  ];
}

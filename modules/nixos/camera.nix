# Camera access at login.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo;

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
in
{
  config = lib.mkIf cfg.hardware.camera.waitForAccess {
    systemd.user.services.wireplumber.serviceConfig.ExecStartPre = [
      "-${waitForCameraAccess}/bin/marchyo-wait-camera-access"
    ];
  };
}

# Global (headless-safe): capture crashed-process core dumps via
# systemd-coredump so `coredumpctl list/info/gdb` can inspect a crash after the
# fact. This is the declarative analog of omarchy's crash-capture toggle.
{ lib, ... }:
{
  # systemd-coredump owns the kernel core_pattern; it journals a backtrace and
  # stores the (compressed) core for later inspection. All bounded so a crash
  # loop cannot fill the disk. mkDefault throughout so a host can override.
  systemd.coredump = {
    enable = lib.mkDefault true;
    settings.Coredump = {
      Storage = lib.mkDefault "external";
      Compress = lib.mkDefault "yes";
      MaxUse = lib.mkDefault "2G";
      ProcessSizeMax = lib.mkDefault "8G";
    };
  };
}

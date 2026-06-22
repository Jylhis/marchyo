# Hardened, multiplexing-friendly SSH client defaults for the user.
#
# enableDefaultConfig is off because we supply our own "*" match block instead
# of home-manager's builtin one (HM errors if both define "*"). Every field is
# mkDefault, so a consumer can override any single setting, the whole "*" block,
# or disable the module entirely with `programs.ssh.enable = false`.
{ lib, ... }:
{
  programs.ssh = {
    enable = lib.mkDefault true;
    enableDefaultConfig = lib.mkDefault false;
    settings = {
      "*" = {
        # Connection multiplexing: reuse one TCP connection per host so repeat
        # sessions (and tools like git/rsync over ssh) skip the handshake.
        ControlMaster = lib.mkDefault "auto";
        ControlPath = lib.mkDefault "~/.ssh/master-%r@%n:%p";
        ControlPersist = lib.mkDefault "10m";

        # Keepalive so idle sessions survive NAT / firewall idle timeouts.
        ServerAliveInterval = lib.mkDefault 60;
        ServerAliveCountMax = lib.mkDefault 3;

        # Conservative agent / forwarding posture: opt in per-host, not globally.
        ForwardAgent = lib.mkDefault false;
        AddKeysToAgent = lib.mkDefault "no";
        Compression = lib.mkDefault false;
        HashKnownHosts = lib.mkDefault false;
        UserKnownHostsFile = lib.mkDefault "~/.ssh/known_hosts";
      };
    };
  };
}

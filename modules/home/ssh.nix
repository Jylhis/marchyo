{ lib, ... }:

{
  programs.ssh = {
    enable = lib.mkDefault true;

    # Connection multiplexing - reuse existing connections for faster subsequent connections
    # This creates a single connection that multiple SSH sessions can share
    controlMaster = "auto";
    controlPath = "~/.ssh/control-%r@%h:%p";
    # Keep the master connection alive for 10 minutes after the last session closes
    controlPersist = "10m";

    # Send keepalive packets every 60 seconds to prevent connection timeouts
    serverAliveInterval = 60;

    # Automatically add SSH keys to the agent when first used
    # Avoids having to run ssh-add manually
    addKeysToAgent = "yes";

    # Enable compression for faster transfers over slow connections
    compression = true;

    # Hash known hosts file for better privacy
    # Makes it harder to enumerate which hosts you've connected to
    hashKnownHosts = true;

    # Common host configurations
    matchBlocks = {
      # GitHub - use git user and ensure keys are added to agent
      "github.com" = {
        user = "git";
        addKeysToAgent = "yes";
      };

      # GitLab - use git user
      "gitlab.com" = {
        user = "git";
        addKeysToAgent = "yes";
      };

      # Local network hosts - skip strict host key checking
      # Useful for homelab, development VMs, etc.
      # WARNING: Only use for trusted local networks
      "*.local" = {
        extraOptions = {
          StrictHostKeyChecking = "no";
          UserKnownHostsFile = "/dev/null";
        };
      };

      # Another common pattern for local development
      "192.168.*.*" = {
        extraOptions = {
          StrictHostKeyChecking = "no";
          UserKnownHostsFile = "/dev/null";
        };
      };
    };
  };

  # Enable SSH agent to manage SSH keys
  # The agent holds decrypted keys in memory so you don't need to enter passphrases repeatedly
  services.ssh-agent.enable = lib.mkDefault true;
}

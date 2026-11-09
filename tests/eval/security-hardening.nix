{ helpers, lib, ... }:
let
  inherit (helpers) testNixOSCheck testNixOSFails withTestUser;

  testKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl test@example";

  sshOn = extra: withTestUser (lib.recursiveUpdate { marchyo.security.ssh.enable = true; } extra);

  udevText = c: c.services.udev.extraRules;
  kyberRule =
    c:
    lib.findFirst (l: lib.hasInfix ''ATTR{queue/scheduler}="kyber"'' l) "" (
      lib.splitString "\n" (udevText c)
    );
in
{
  eval-security-ssh-hardening =
    testNixOSCheck "security-ssh-hardening"
      (
        c:
        let
          s = c.services.openssh.settings;
        in
        c.services.openssh.enable
        && s.PasswordAuthentication == false
        && s.KbdInteractiveAuthentication == false
        && s.PermitRootLogin == "no"
      )
      (sshOn {
        users.users.testuser.openssh.authorizedKeys.keys = [ testKey ];
      });

  # testuser is in wheel (marchyo.users) and has no key.
  eval-security-ssh-requires-keys =
    testNixOSFails "security-ssh-requires-keys" "authorized SSH key: testuser."
      (sshOn { });

  eval-security-ssh-listed-user-requires-keys =
    testNixOSFails "security-ssh-listed-user-requires-keys" "authorized SSH key: deploy."
      (sshOn {
        users.users.testuser.openssh.authorizedKeys.keys = [ testKey ];
        users.users.deploy = {
          isNormalUser = true;
          group = "users";
        };
        marchyo.security.ssh.users = [ "deploy" ];
      });

  eval-security-ssh-primary-wheel-requires-keys =
    testNixOSFails "security-ssh-primary-wheel-requires-keys" "authorized SSH key: ops."
      (sshOn {
        users.users.testuser.openssh.authorizedKeys.keys = [ testKey ];
        users.users.ops = {
          isNormalUser = true;
          group = "wheel";
        };
      });

  # "none" switches the CA or command off, so keys are still required.
  eval-security-ssh-none-ca-requires-keys =
    testNixOSFails "security-ssh-none-ca-requires-keys" "authorized SSH key: testuser."
      (sshOn {
        services.openssh.settings.TrustedUserCAKeys = "none";
        services.openssh.settings.AuthorizedKeysCommand = "none";
      });

  # Not in wheel, not listed, or no login shell: sshd does not need a key for it.
  eval-security-ssh-ignores-ineligible =
    testNixOSCheck "security-ssh-ignores-ineligible" (c: c.services.openssh.enable)
      (sshOn {
        users.users.testuser.openssh.authorizedKeys.keys = [ testKey ];
        users.users.guest = {
          isNormalUser = true;
          group = "users";
        };
        users.users.robot = {
          isNormalUser = true;
          group = "users";
          extraGroups = [ "wheel" ];
          shell = "/run/current-system/sw/bin/nologin";
        };
      });

  eval-security-ssh-keyfiles =
    testNixOSCheck "security-ssh-keyfiles" (c: c.services.openssh.enable)
      (sshOn {
        users.users.testuser.openssh.authorizedKeys.keyFiles = [ ./fixtures/ssh-test.pub ];
      });

  eval-security-ssh-ca = testNixOSCheck "security-ssh-ca" (c: c.services.openssh.enable) (sshOn {
    services.openssh.settings.TrustedUserCAKeys = "/etc/ssh/user_ca.pub";
  });

  eval-security-ssh-keys-command =
    testNixOSCheck "security-ssh-keys-command" (c: c.services.openssh.enable)
      (sshOn {
        services.openssh.authorizedKeysCommand = "/run/current-system/sw/bin/true";
      });

  eval-security-ssh-allow-no-keys =
    testNixOSCheck "security-ssh-allow-no-keys" (c: c.services.openssh.enable)
      (sshOn {
        marchyo.security.ssh.allowNoKeys = true;
      });

  # The check follows sshd itself, not the marchyo flag alone.
  eval-security-ssh-sshd-forced-off =
    testNixOSCheck "security-ssh-sshd-forced-off" (c: !c.services.openssh.enable)
      (sshOn {
        services.openssh.enable = lib.mkForce false;
      });

  eval-security-ssh-default-off = testNixOSCheck "security-ssh-default-off" (
    c: !c.services.openssh.enable
  ) (withTestUser { });

  eval-security-sudo-timeout-default = testNixOSCheck "security-sudo-timeout-default" (
    c: lib.hasInfix "Defaults timestamp_timeout=10\n" c.security.sudo.extraConfig
  ) (withTestUser { });

  eval-security-sudo-timeout-custom =
    testNixOSCheck "security-sudo-timeout-custom"
      (c: lib.hasInfix "Defaults timestamp_timeout=0\n" c.security.sudo.extraConfig)
      (withTestUser {
        marchyo.security.sudo.timestampTimeout = 0;
      });

  eval-security-network-sysctls-default = testNixOSCheck "security-network-sysctls-default" (
    c:
    let
      s = c.boot.kernel.sysctl;
    in
    s."net.ipv4.conf.all.arp_ignore" == 1
    && s."net.ipv4.conf.default.arp_ignore" == 1
    && s."net.ipv4.conf.all.arp_announce" == 2
    && s."net.ipv4.conf.default.arp_announce" == 2
    && s."net.ipv4.tcp_mtu_probing" == 1
    && s."net.ipv4.tcp_congestion_control" == "bbr"
    && s."net.core.default_qdisc" == "fq"
    && builtins.elem "tcp_bbr" c.boot.kernelModules
  ) (withTestUser { });

  eval-security-kyber-rule-default = testNixOSCheck "security-kyber-rule-default" (
    c:
    let
      r = kyberRule c;
    in
    lib.hasInfix ''ENV{DEVTYPE}=="disk"'' r
    && lib.hasInfix ''KERNEL=="nvme*|sd*|mmcblk*|vd*"'' r
    && lib.hasInfix ''ATTR{queue/rotational}=="0"'' r
    && lib.hasInfix ''ATTR{queue/zoned}=="none"'' r
    && !(lib.hasInfix "mq-deadline" (udevText c))
  ) (withTestUser { });

  # NVMe tuning owns the NVMe scheduler; kyber keeps the other disks.
  eval-security-kyber-rule-nvme-tuned =
    testNixOSCheck "security-kyber-rule-nvme-tuned"
      (
        c:
        lib.hasInfix ''KERNEL=="sd*|mmcblk*|vd*"'' (kyberRule c)
        && lib.hasInfix ''ATTR{queue/scheduler}="mq-deadline"'' (udevText c)
      )
      (withTestUser {
        marchyo.performance.tuning.enable = true;
      });

  eval-security-kyber-rule-off =
    testNixOSCheck "security-kyber-rule-off" (c: kyberRule c == "")
      (withTestUser {
        marchyo.performance.kyber.enable = false;
      });
}

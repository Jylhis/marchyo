# SSH hardening, sudo, network sysctls and the kyber I/O scheduler rule.
# Every reference system that turns marchyo.security.ssh on gives each
# eligible login user a key (or a central source), so its own assertions pass.
{ lib, ... }:
let
  testKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl test@example";

  udevText = c: c.services.udev.extraRules;
  kyberRule =
    c:
    lib.findFirst (l: lib.hasInfix ''ATTR{queue/scheduler}="kyber"'' l) "" (
      lib.splitString "\n" (udevText c)
    );
  sshd = c: c.services.openssh.enable;
in
{
  refs = {
    headless-tweaks = {
      eval-security-ssh-hardening =
        c:
        let
          s = c.services.openssh.settings;
        in
        c.services.openssh.enable
        && s.PasswordAuthentication == false
        && s.KbdInteractiveAuthentication == false
        && s.PermitRootLogin == "no";

      # Not in wheel, not listed, or no login shell (guest, robot): sshd does not
      # need a key for it.
      eval-security-ssh-ignores-ineligible = sshd;

      # headless-tweaks: marchyo.security.sudo.timestampTimeout = 0.
      eval-security-sudo-timeout-custom =
        c: lib.hasInfix "Defaults timestamp_timeout=0\n" c.security.sudo.extraConfig;
    };

    headless-tweaks-2 = {
      eval-security-ssh-keyfiles = sshd;

      # NVMe tuning owns the NVMe scheduler; kyber keeps the other disks.
      eval-security-kyber-rule-nvme-tuned =
        c:
        lib.hasInfix ''KERNEL=="sd*|mmcblk*|vd*"'' (kyberRule c)
        && lib.hasInfix ''ATTR{queue/scheduler}="mq-deadline"'' (udevText c);
    };

    headless-tweaks-3 = {
      eval-security-ssh-ca = sshd;
      eval-security-kyber-rule-off = c: kyberRule c == "";
    };

    headless-tweaks-4.eval-security-ssh-keys-command = sshd;

    dev-tweaks.eval-security-ssh-allow-no-keys = sshd;

    # The check follows sshd itself, not the marchyo flag alone (desktop-off:
    # the flag on, services.openssh.enable forced off).
    desktop-off.eval-security-ssh-sshd-forced-off = c: !(sshd c);

    headless = {
      eval-security-ssh-default-off = c: !(sshd c);

      eval-security-sudo-timeout-default =
        c: lib.hasInfix "Defaults timestamp_timeout=10\n" c.security.sudo.extraConfig;

      eval-security-network-sysctls-default =
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
        && builtins.elem "tcp_bbr" c.boot.kernelModules;

      eval-security-kyber-rule-default =
        c:
        let
          r = kyberRule c;
        in
        lib.hasInfix ''ENV{DEVTYPE}=="disk"'' r
        && lib.hasInfix ''KERNEL=="nvme*|sd*|mmcblk*|vd*"'' r
        && lib.hasInfix ''ATTR{queue/rotational}=="0"'' r
        && lib.hasInfix ''ATTR{queue/zoned}=="none"'' r
        && !(lib.hasInfix "mq-deadline" (udevText c));
    };
  };

  refConfig = {
    headless-tweaks = {
      marchyo.security.ssh.enable = true;
      marchyo.security.sudo.timestampTimeout = 0;
      users.users = {
        testuser.openssh.authorizedKeys.keys = [ testKey ];
        guest = {
          isNormalUser = true;
          group = "users";
        };
        robot = {
          isNormalUser = true;
          group = "users";
          extraGroups = [ "wheel" ];
          shell = "/run/current-system/sw/bin/nologin";
        };
      };
    };
    headless-tweaks-2 = {
      marchyo.security.ssh.enable = true;
      users.users.testuser.openssh.authorizedKeys.keyFiles = [ ./fixtures/ssh-test.pub ];
    };
    headless-tweaks-3 = {
      marchyo.security.ssh.enable = true;
      services.openssh.settings.TrustedUserCAKeys = "/etc/ssh/user_ca.pub";
      marchyo.performance.kyber.enable = false;
    };
    headless-tweaks-4 = {
      marchyo.security.ssh.enable = true;
      services.openssh.authorizedKeysCommand = "/run/current-system/sw/bin/true";
    };
    dev-tweaks.marchyo.security.ssh = {
      enable = true;
      allowNoKeys = true;
    };
    desktop-off = {
      marchyo.security.ssh.enable = true;
      services.openssh.enable = lib.mkForce false;
    };
  };

  failing = {
    # testuser is in wheel (marchyo.users) and has no key (misconfigured).
    eval-security-ssh-requires-keys = {
      on = "misconfigured";
      expect = "authorized SSH key: testuser.";
    };

    # A user listed in marchyo.security.ssh.users (deploy) and a wheel member
    # (ops) without keys are both reported (misconfigured-2). (Merges the
    # former eval-security-ssh-listed-user-requires-keys and
    # eval-security-ssh-primary-wheel-requires-keys.)
    eval-security-ssh-listed-and-wheel-users-require-keys = {
      on = "misconfigured-2";
      expect = "authorized SSH key: deploy, ops.";
    };

    # "none" switches the CA or command off, so keys are still required
    # (misconfigured-3).
    eval-security-ssh-none-ca-requires-keys = {
      on = "misconfigured-3";
      expect = "authorized SSH key: testuser.";
    };
  };

  failingConfig = {
    misconfigured.marchyo.security.ssh.enable = true;
    misconfigured-2 = {
      marchyo.security.ssh.enable = true;
      marchyo.security.ssh.users = [ "deploy" ];
      users.users = {
        testuser.openssh.authorizedKeys.keys = [ testKey ];
        deploy = {
          isNormalUser = true;
          group = "users";
        };
        ops = {
          isNormalUser = true;
          group = "wheel";
        };
      };
    };
    misconfigured-3 = {
      marchyo.security.ssh.enable = true;
      services.openssh.settings.TrustedUserCAKeys = "none";
      services.openssh.settings.AuthorizedKeysCommand = "none";
    };
  };
}

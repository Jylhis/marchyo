_:
{
  # Networking stays unconditional — a headless host wants it too.
  # The impala Wi-Fi TUI lives in packages.nix (tuiTools); it was duplicated
  # here previously.
  networking = {
    networkmanager = {
      enable = true;
    };
  };
}

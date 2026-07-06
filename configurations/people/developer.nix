# Reference identity used by the marchyo example configurations.
# Host-specific bits (demo password, getty autologin) stay in the host
# configs in outputs.nix.
{
  marchyo.identity.users.developer = {
    fullName = "Marchyo Developer";
    email = "dev@example.org";
    sudo = true;
    # "wheel" is implied by sudo; keeping it first preserves the exact
    # extraGroups order the inline users.users block produced.
    groups = [
      "wheel"
      "networkmanager"
    ];
  };
}

# Aggregator for identity declarations — one file per person/account.
# Hosts import this directory and add host-specific overrides
# (e.g. opting a disabled system account in with
# `marchyo.identity.users.<name>.enable = true;`).
{
  imports = [
    ./developer.nix
  ];
}

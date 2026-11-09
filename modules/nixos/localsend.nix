# LocalSend file sharing ships with the desktop (programs.localsend, which
# also opens port 53317 by default). `marchyo share` and the Nautilus
# "Send with LocalSend" script follow programs.localsend.enable.
{
  config,
  lib,
  ...
}:
{
  programs.localsend.enable = lib.mkDefault config.marchyo.desktop.enable;
}

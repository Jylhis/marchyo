{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    papers # Document viewer
    xournalpp # Write to PDFs
    libreoffice # Standard office suite
  ];
}

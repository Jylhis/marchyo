(import (
  let
    lock = builtins.fromJSON (builtins.readFile ./flake.lock);
    nodeSrc = lock.nodes.flake-compat.locked;
  in
  fetchTarball {
    url = "https://github.com/edolstra/flake-compat/archive/${nodeSrc.rev}.tar.gz";
    sha256 = nodeSrc.narHash;
  }
) { src = ./.; }).defaultNix

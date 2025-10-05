# DEPRECATED: This module is deprecated in favor of modules/nixos/virtualization.nix
# Container functionality has been moved to the virtualization module which provides
# both VM and container virtualization in a unified interface.
#
# Migration guide:
# - marchyo.virtualization.enable replaces this module's functionality
# - marchyo.virtualization.enableDocker controls Docker runtime
# - marchyo.virtualization.enablePodman controls Podman runtime
#
# This file is kept for backward compatibility but does nothing.
# It will be removed in a future release.
_: { }

# nixpkgs-style derivation for the OpenViking `ov` CLI.
#
# OpenViking is a local-capable context database ("context filesystem") for AI
# agents. Vendored from Jylhis/skills#56 (hashes computed there). Written to
# nixpkgs conventions so it can be dropped into nixpkgs at
# pkgs/by-name/op/openviking/package.nix unchanged.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  cmake,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "openviking";
  version = "0.3.24";

  src = fetchFromGitHub {
    owner = "volcengine";
    repo = "OpenViking";
    tag = "cli@${finalAttrs.version}";
    hash = "sha256-rD5LosriJGU0bIBRx46kmOGM4MJBvx0o0swB8gcBxw4=";
  };

  cargoHash = "sha256-l1dwyNO+DiKdeo1Oe+vf6iuJZ1OqBMfmqzT6QM/2OSU=";

  buildAndTestSubdir = "crates/ov_cli";

  env.OPENVIKING_VERSION = finalAttrs.version;

  nativeBuildInputs = [ cmake ];

  doCheck = false;

  meta = {
    description = "Command-line client for OpenViking, a context filesystem for AI agents";
    homepage = "https://openviking.ai";
    changelog = "https://github.com/volcengine/OpenViking/releases/tag/cli@${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    mainProgram = "ov";
    maintainers = [ ];
    platforms = lib.platforms.unix;
  };
})

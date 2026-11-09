import {
  detectFlake,
  usageError,
  type FlakeLocation,
  type Runtime,
  tr,
} from "@marchyo/core";

// Detect the flake or emit the canonical usage error (shared by rebuild,
// update, upgrade, and theme). Returns null after reporting so callers can
// simply `if (!flake) return 2;`.
export async function requireFlake(
  rt: Runtime,
): Promise<FlakeLocation | null> {
  const flake = await detectFlake();
  if (!flake) {
    usageError(
      rt,
      tr("require-flake.couldNotDetectFlake"),
      "place a flake at /etc/nixos/flake.nix or run from a flake directory",
    );
    return null;
  }
  return flake;
}

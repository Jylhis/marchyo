import { existsSync, rmSync } from "node:fs";
import { join } from "node:path";
import { ok, info, data, usageError, type Runtime } from "@marchyo/core";

const NAME_RE = /^[a-z][a-z0-9-]*$/;

const MODULE_TEMPLATE = (name: string) => `{ config, lib, ... }:
let
  cfg = config.marchyo.${name};
in
{
  options.marchyo.${name} = {
    enable = lib.mkEnableOption "the ${name} module";
  };

  config = lib.mkIf cfg.enable {
    # TODO: implement ${name}
  };
}
`;

// One file per module under tests/eval/, auto-discovered by tests/default.nix
// via lib/discover-modules.nix — the same discovery that picks up the module
// itself. Mirrors the existing suites, e.g. tests/eval/cli.nix.
const TEST_TEMPLATE = (name: string) => `{ helpers, ... }:
let
  inherit (helpers) testNixOS withTestUser;
in
{
  # ${name}: smoke test for module evaluation
  eval-${name} = testNixOS "${name}" (withTestUser {
    marchyo.${name}.enable = true;
  });
}
`;

export async function runScaffoldModule(
  rt: Runtime,
  name: string,
  repoPath: string,
): Promise<number> {
  if (!NAME_RE.test(name)) {
    return usageError(
      rt,
      `name must match /^[a-z][a-z0-9-]*$/ (got '${name}')`,
      `marchyoctl scaffold module my-feature`,
    );
  }

  const modulePath = join(repoPath, "modules", "nixos", `${name}.nix`);
  const testPath = join(repoPath, "tests", "eval", `${name}.nix`);
  // Checkout markers, both of which are also the directories written into.
  // Deliberately not tests/module-tests.nix, which this used to require and
  // which has never existed in this layout: the command aborted against every
  // real checkout with a misleading "pass --repo" hint.
  const modulesDir = join(repoPath, "modules", "nixos");
  const testsDir = join(repoPath, "tests", "eval");

  for (const dir of [modulesDir, testsDir]) {
    if (!existsSync(dir)) {
      return usageError(
        rt,
        `${dir} not found`,
        `pass --repo <path-to-marchyo-checkout>`,
      );
    }
  }

  // Every check before the first write. The previous version wrote the module
  // and only then discovered it could not edit modules/nixos/default.nix,
  // leaving a stray auto-discovered module behind on a reported failure.
  for (const path of [modulePath, testPath]) {
    if (existsSync(path)) {
      return usageError(rt, `${path} already exists`);
    }
  }

  const created: string[] = [];
  try {
    await Bun.write(modulePath, MODULE_TEMPLATE(name));
    created.push(modulePath);
    await Bun.write(testPath, TEST_TEMPLATE(name));
    created.push(testPath);
  } catch (error) {
    // Leave nothing half-applied.
    for (const path of created) rmSync(path, { force: true });
    return usageError(
      rt,
      `could not write the scaffold: ${String(error)}`,
      `check write permissions on ${modulesDir} and ${testsDir}`,
    );
  }

  for (const path of created) ok(rt, `created ${path}`);

  // No edit to modules/nixos/default.nix: lib/discover-modules.nix imports
  // every .nix directly under modules/nixos/, and tests/default.nix does the
  // same for tests/eval/, so both files are already wired up. The old
  // regex-based import edit could not match the current default.nix anyway.
  info(rt, `both files are auto-discovered; no import list to update.`);
  info(rt, `next: implement ${modulePath}, then run 'just check' to validate.`);

  data(rt, { name, created }, () => created.join("\n"));
  return 0;
}

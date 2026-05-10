import { existsSync } from "node:fs";
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
  const importsPath = join(repoPath, "modules", "nixos", "default.nix");
  const testsPath = join(repoPath, "tests", "module-tests.nix");

  if (existsSync(modulePath)) {
    return usageError(rt, `${modulePath} already exists`);
  }
  if (!existsSync(importsPath)) {
    return usageError(
      rt,
      `${importsPath} not found`,
      `pass --repo <path-to-marchyo-checkout>`,
    );
  }
  if (!existsSync(testsPath)) {
    return usageError(
      rt,
      `${testsPath} not found`,
      `pass --repo <path-to-marchyo-checkout>`,
    );
  }

  await Bun.write(modulePath, MODULE_TEMPLATE(name));
  ok(rt, `created ${modulePath}`);
  const created: string[] = [modulePath];

  const imports = await Bun.file(importsPath).text();
  const importLine = `    ./${name}.nix\n`;
  if (imports.includes(importLine.trim())) {
    info(rt, `${importsPath} already imports ${name}.nix`);
  } else {
    const updated = imports.replace(
      /(\s*)\];\n\s*config = \{/,
      (_match, indent) =>
        `${indent}  ${importLine.trim()}\n${indent}];\n${indent}config = {`,
    );
    if (updated === imports) {
      // Fail loudly per §2.6: name the field, the expected shape, and the
      // recovery action. Don't ship a silent half-success that produces a
      // broken default.nix.
      return usageError(
        rt,
        `could not auto-edit ${importsPath}: imports/config block not in expected shape`,
        `add './${name}.nix' to the imports list in ${importsPath} manually, then re-run 'just check'`,
      );
    }
    await Bun.write(importsPath, updated);
    ok(rt, `updated ${importsPath}`);
    created.push(importsPath);
  }

  const tests = await Bun.file(testsPath).text();
  const testStub = `\n  # ${name}: smoke test for module evaluation
  eval-${name} = testNixOS "${name}" (withTestUser {
    marchyo.${name}.enable = true;
  });
`;
  if (tests.includes(`eval-${name} = testNixOS`)) {
    info(rt, `${testsPath} already has eval-${name}`);
  } else {
    const updated = tests.replace(/\}\s*$/, `${testStub}}\n`);
    await Bun.write(testsPath, updated);
    ok(rt, `updated ${testsPath}`);
    created.push(testsPath);
  }

  info(rt, `next: implement ${modulePath}, then run 'just check' to validate.`);

  data(rt, { name, created }, () => created.join("\n"));
  return 0;
}

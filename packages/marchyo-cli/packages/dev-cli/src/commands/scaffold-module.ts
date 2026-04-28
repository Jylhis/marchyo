import { existsSync } from "node:fs";
import { join } from "node:path";

const NAME_RE = /^[a-z][a-z0-9-]*$/;

const MODULE_TEMPLATE = (name: string) => `{ config, lib, ... }:
let
  cfg = config.marchyo.${name};
in
{
  options.marchyo.${name} = {
    enable = lib.mkEnableOption "${name} module";
  };

  config = lib.mkIf cfg.enable {
    # TODO: implement ${name}
  };
}
`;

export async function runScaffoldModule(
  name: string,
  repoPath: string,
): Promise<void> {
  if (!NAME_RE.test(name)) {
    console.error(
      `error: name must match ${NAME_RE} (got '${name}')`,
    );
    process.exit(1);
  }

  const modulePath = join(repoPath, "modules", "nixos", `${name}.nix`);
  const importsPath = join(repoPath, "modules", "nixos", "default.nix");
  const testsPath = join(repoPath, "tests", "module-tests.nix");

  if (existsSync(modulePath)) {
    console.error(`error: ${modulePath} already exists`);
    process.exit(1);
  }
  if (!existsSync(importsPath)) {
    console.error(`error: ${importsPath} not found — is --repo correct?`);
    process.exit(1);
  }
  if (!existsSync(testsPath)) {
    console.error(`error: ${testsPath} not found — is --repo correct?`);
    process.exit(1);
  }

  await Bun.write(modulePath, MODULE_TEMPLATE(name));
  console.log(`created ${modulePath}`);

  const imports = await Bun.file(importsPath).text();
  const importLine = `    ./${name}.nix\n`;
  if (imports.includes(importLine.trim())) {
    console.log(`(${importsPath} already imports ${name}.nix)`);
  } else {
    const updated = imports.replace(
      /(\s*)\];\n\s*config = \{/,
      (_match, indent) => `${indent}  ${importLine.trim()}\n${indent}];\n${indent}config = {`,
    );
    if (updated === imports) {
      console.warn(
        `warn: could not auto-edit ${importsPath}; add './${name}.nix' to its imports list manually`,
      );
    } else {
      await Bun.write(importsPath, updated);
      console.log(`updated ${importsPath}`);
    }
  }

  const tests = await Bun.file(testsPath).text();
  const testStub = `\n  # ${name}: smoke test for module evaluation
  eval-${name} = testNixOS "${name}" (withTestUser {
    marchyo.${name}.enable = true;
  });
`;
  if (tests.includes(`eval-${name} = testNixOS`)) {
    console.log(`(${testsPath} already has eval-${name})`);
  } else {
    const updated = tests.replace(/\}\s*$/, `${testStub}}\n`);
    await Bun.write(testsPath, updated);
    console.log(`updated ${testsPath}`);
  }

  console.log(
    `\nNext: implement ${modulePath}, then run 'just check' to validate.`,
  );
}

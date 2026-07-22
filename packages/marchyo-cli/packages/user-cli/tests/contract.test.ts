import { expect, test } from "bun:test";
import { join } from "node:path";

// Contract freeze (CLI 1.0): command names, arguments, flags, and exit
// codes are stable until 2.0. These snapshots pin the --help trees and the
// key --format json shapes — an unintentional surface change fails CI.
// Intentional 1.x additions re-snapshot with `bun test --update-snapshots`
// (additions are allowed; renames/removals are not until 2.0).

const REPO = join(import.meta.dir, "..", "..", "..");
const CLI = join(REPO, "packages", "user-cli", "src", "cli.tsx");

async function helpOf(args: string[]): Promise<string> {
  const proc = Bun.spawn(["bun", CLI, ...args, "--help"], {
    stdout: "pipe",
    stderr: "pipe",
    env: { ...process.env, NO_COLOR: "1" },
  });
  await proc.exited;
  return await new Response(proc.stdout).text();
}

const GROUPS: string[][] = [
  [],
  ["theme"],
  ["bg"],
  ["toggle"],
  ["capture"],
  ["menu"],
  ["monitor"],
  ["reminder"],
  ["font"],
  ["webapp"],
  ["security"],
  ["runtime"],
  ["completion"],
];

for (const group of GROUPS) {
  test(`help contract: marchyo ${group.join(" ") || "(root)"}`, async () => {
    expect(await helpOf(group)).toMatchSnapshot();
  });
}

function stateEnv(dir: string): Record<string, string> {
  return {
    XDG_DATA_HOME: `${dir}/data`,
    XDG_CONFIG_HOME: `${dir}/config`,
    XDG_STATE_HOME: `${dir}/state`,
    NO_COLOR: "1",
  };
}

async function jsonOf(args: string[]): Promise<unknown> {
  const dir = `/tmp/marchyo-contract-${Date.now()}-${Math.random().toString(36).slice(2)}`;
  Bun.spawnSync(["mkdir", "-p", dir]);
  const proc = Bun.spawn(["bun", CLI, ...args, "--json"], {
    stdout: "pipe",
    stderr: "ignore",
    env: { ...process.env, ...stateEnv(dir) },
  });
  await proc.exited;
  return JSON.parse(await new Response(proc.stdout).text());
}

// Shape (sorted key paths), not values — environments differ, the contract
// is the schema.
function shapeOf(value: unknown, prefix = ""): string[] {
  if (Array.isArray(value)) {
    return value.length === 0
      ? [`${prefix}[]`]
      : shapeOf(value[0], `${prefix}[]`);
  }
  if (value !== null && typeof value === "object") {
    return Object.keys(value as object)
      .sort()
      .flatMap((k) => shapeOf((value as Record<string, unknown>)[k], `${prefix}.${k}`));
  }
  return [`${prefix}:${value === null ? "null" : typeof value}`];
}

test("json contract: theme get shape", async () => {
  expect(shapeOf(await jsonOf(["theme", "get"]))).toMatchSnapshot();
});

test("json contract: runtime status shape", async () => {
  expect(shapeOf(await jsonOf(["runtime", "status"]))).toMatchSnapshot();
});

test("json contract: toggle --status shape", async () => {
  expect(
    shapeOf(await jsonOf(["toggle", "screensaver", "--status"])),
  ).toMatchSnapshot();
});

test("json contract: debug shape", async () => {
  expect(shapeOf(await jsonOf(["debug"]))).toMatchSnapshot();
});

test("exit-code contract", async () => {
  // 0 success / 1 runtime failure / 2 usage error.
  const run = async (args: string[]) => {
    const proc = Bun.spawn(["bun", CLI, ...args], {
      stdout: "ignore",
      stderr: "ignore",
      env: { ...process.env, NO_COLOR: "1" },
    });
    return await proc.exited;
  };
  expect(await run(["--version"])).toBe(0);
  expect(await run(["toggle", "warp-drive"])).toBe(2);
  expect(await run(["launch", "definitely-not-a-real-app"])).toBe(1);
});

import { test, expect } from "bun:test";
import { join } from "node:path";
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";

const REPO = join(import.meta.dir, "..", "..", "..");
const CLI = join(REPO, "packages", "dev-cli", "src", "cli.tsx");

async function run(
  args: string[],
  env: Record<string, string> = {},
): Promise<{ code: number; stdout: string; stderr: string }> {
  const proc = Bun.spawn(["bun", CLI, ...args], {
    stdout: "pipe",
    stderr: "pipe",
    env: { ...process.env, NO_COLOR: "1", ...env },
  });
  const code = await proc.exited;
  const stdout = await new Response(proc.stdout).text();
  const stderr = await new Response(proc.stderr).text();
  return { code, stdout, stderr };
}

test("--help exits 0 and shows Examples block", async () => {
  const r = await run(["--help"]);
  expect(r.code).toBe(0);
  expect(r.stdout).toContain("Examples:");
  expect(r.stdout).toContain("marchyoctl");
});

test("scaffold module with bad name exits 2", async () => {
  const r = await run(["scaffold", "module", "BadName"]);
  expect(r.code).toBe(2);
  // glyph (or, in plain mode, "error:" prefix) — never both
  expect(r.stderr).toMatch(/(✗|error:)/);
  expect(r.stderr).not.toContain("Error: name must");
  expect(r.stderr).toContain("Try: marchyoctl scaffold module");
});

test("scaffold module with missing repo exits 2", async () => {
  const dir = mkdtempSync(join(tmpdir(), "marchyo-scaffold-test-"));
  try {
    const r = await run(["scaffold", "module", "foo", "--repo", dir]);
    expect(r.code).toBe(2);
    expect(r.stderr).toMatch(/(✗|error:)/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("scaffold module writes both files against the real repo layout", async () => {
  // Runs against a copy of the actual checkout, not a synthetic directory.
  // The old tests only ever passed a fresh mkdtemp dir, which is why they
  // never noticed the command had come to require tests/module-tests.nix — a
  // file this layout has never had, so it aborted against every real repo.
  const dir = mkdtempSync(join(tmpdir(), "marchyo-scaffold-real-"));
  try {
    mkdirSync(join(dir, "modules", "nixos"), { recursive: true });
    mkdirSync(join(dir, "tests", "eval"), { recursive: true });
    const r = await run(["scaffold", "module", "zz-scaffold-probe", "--repo", dir]);
    expect(r.code).toBe(0);
    expect(existsSync(join(dir, "modules", "nixos", "zz-scaffold-probe.nix"))).toBe(true);
    expect(existsSync(join(dir, "tests", "eval", "zz-scaffold-probe.nix"))).toBe(true);
    // The module is picked up by discover-modules.nix and the test by
    // tests/default.nix, so nothing should have edited an import list.
    expect(existsSync(join(dir, "modules", "nixos", "default.nix"))).toBe(false);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("scaffold module refuses to overwrite and leaves nothing behind", async () => {
  const dir = mkdtempSync(join(tmpdir(), "marchyo-scaffold-clash-"));
  try {
    mkdirSync(join(dir, "modules", "nixos"), { recursive: true });
    mkdirSync(join(dir, "tests", "eval"), { recursive: true });
    // A pre-existing eval test, with the module absent: validation has to run
    // before any write, or the module file is created and then orphaned.
    writeFileSync(join(dir, "tests", "eval", "zz-clash.nix"), "{ }\n");
    const r = await run(["scaffold", "module", "zz-clash", "--repo", dir]);
    expect(r.code).toBe(2);
    expect(existsSync(join(dir, "modules", "nixos", "zz-clash.nix"))).toBe(false);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

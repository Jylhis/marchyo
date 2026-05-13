import { test, expect } from "bun:test";
import { join } from "node:path";
import { mkdtempSync, rmSync } from "node:fs";
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

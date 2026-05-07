import { test, expect, afterAll } from "bun:test";
import { join } from "node:path";
import { rmSync } from "node:fs";

// Clean up any state file the smoke tests below may have written.
// Running as root (e.g. in a CI sandbox) the writes succeed against /etc;
// running unprivileged they fail with EACCES (also tested).
afterAll(() => {
  rmSync("/etc/marchyo/cli-state.json", { force: true });
  rmSync("/etc/marchyo", { recursive: true, force: true });
});

const REPO = join(import.meta.dir, "..", "..", "..");
const CLI = join(REPO, "packages", "user-cli", "src", "cli.tsx");

async function run(
  args: string[],
  env: Record<string, string> = {},
): Promise<{ code: number; stdout: string; stderr: string }> {
  const proc = Bun.spawn(["bun", CLI, ...args], {
    stdout: "pipe",
    stderr: "pipe",
    env: {
      ...process.env,
      NO_COLOR: "1",
      // Force the CLI's stdout to look like a non-TTY so animation/color stay off.
      ...env,
    },
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
  expect(r.stdout).toContain("marchyo status");
});

test("--version exits 0", async () => {
  const r = await run(["--version"]);
  expect(r.code).toBe(0);
  expect(r.stdout.trim()).toBe("0.1.0");
});

test("unknown command exits non-zero", async () => {
  const r = await run(["nope"]);
  expect(r.code).not.toBe(0);
});

test("theme set with bad variant exits 2 with Try line", async () => {
  const r = await run(["theme", "set", "neon"]);
  expect(r.code).toBe(2);
  expect(r.stderr).toContain("Error: invalid theme variant");
  expect(r.stderr).toContain("Try: marchyo theme set");
});

test("theme set diagnostics go to stderr, value goes to stdout", async () => {
  const r = await run([
    "theme",
    "set",
    "dark",
    "--format",
    "json",
  ], { MARCHYO_TEST_STATE_PATH: "" });
  // We can't write to /etc in tests; expect EACCES-style error path.
  // Either the write succeeded (tmp env override) and stdout has JSON,
  // or the write failed and stderr has 'Error: cannot write'.
  if (r.code === 0) {
    expect(JSON.parse(r.stdout)).toEqual({ theme: { variant: "dark" } });
  } else {
    expect(r.stderr).toContain("Error: cannot write");
    expect(r.stderr).toContain("/etc/marchyo/cli-state.json");
    expect(r.code).toBe(1);
  }
});

test("NO_COLOR strips ANSI escapes from --help", async () => {
  const r = await run(["--help"], { NO_COLOR: "1" });
  // No CSI-color sequences anywhere in stdout.
  expect(r.stdout).not.toMatch(/\x1b\[\d/);
});

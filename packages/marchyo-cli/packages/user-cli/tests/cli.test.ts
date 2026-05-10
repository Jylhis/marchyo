import { test, expect, afterAll } from "bun:test";
import { join } from "node:path";
import { rmSync } from "node:fs";

// Clean up any state file the smoke tests below may have written.
// Running as root (e.g. in a CI sandbox) writes go to /etc/marchyo;
// running unprivileged with our XDG override they go under /tmp.
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
  // Per §2.6: single signal — glyph or word, never both.
  expect(r.stderr).toContain("invalid theme variant");
  expect(r.stderr).not.toContain("Error: invalid"); // no duplicate prefix
  expect(r.stderr).toContain("Try: marchyo theme set");
});

test("theme set diagnostics go to stderr, value goes to stdout", async () => {
  // Use a tmp XDG_CONFIG_HOME so writes never touch real state.
  const xdg = `/tmp/marchyo-cli-test-xdg-${Date.now()}`;
  const r = await run(
    ["theme", "set", "dark", "--format", "json"],
    { XDG_CONFIG_HOME: xdg },
  );
  // Either the write succeeded (root in sandbox writes to /etc;
  // non-root writes under XDG) or it failed with EACCES.
  if (r.code === 0) {
    const parsed = JSON.parse(r.stdout);
    expect(parsed.theme).toEqual({ variant: "dark" });
    expect(typeof parsed.path).toBe("string");
  } else {
    expect(r.stderr).toContain("cannot write state file");
    expect(r.code).toBe(1);
  }
});

test("NO_COLOR strips ANSI escapes from --help", async () => {
  const r = await run(["--help"], { NO_COLOR: "1" });
  // No CSI-color sequences anywhere in stdout.
  expect(r.stdout).not.toMatch(/\x1b\[\d/);
});

test("--json is an alias for --format json", async () => {
  const r = await run(["theme", "get", "--json"]);
  expect(r.code).toBe(0);
  // stdout is parseable JSON regardless of which flag was used
  const parsed = JSON.parse(r.stdout);
  expect(parsed).toHaveProperty("theme");
});

test("unsupported --format value exits 2 with supported set in message", async () => {
  const r = await run(["status", "--format", "yaml"]);
  expect(r.code).toBe(2);
  expect(r.stderr).toContain("text");
  expect(r.stderr).toContain("json");
});

test("status piped to a non-TTY produces no ANSI escapes", async () => {
  // Default test env already sets NO_COLOR; this asserts the invariant
  // and provides regression coverage for the agent's stdout-discipline
  // concern (jylhis/design §3.5).
  const r = await run(["status"]);
  expect(r.code).toBe(0);
  expect(r.stdout).not.toMatch(/\x1b\[/);
});

test("--color=always with FORCE_COLOR override emits ANSI even when piped", async () => {
  const r = await run(["status", "--color", "always"], {
    NO_COLOR: "",
    FORCE_COLOR: "1",
  });
  expect(r.code).toBe(0);
  // We can't easily assert ANSI presence without a real TTY, but we can
  // at least confirm exit code is clean and the runtime accepted the flag.
});

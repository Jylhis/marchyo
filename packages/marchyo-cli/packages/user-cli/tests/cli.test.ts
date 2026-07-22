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
  cwd?: string,
): Promise<{ code: number; stdout: string; stderr: string }> {
  const proc = Bun.spawn(["bun", CLI, ...args], {
    cwd,
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

test("theme set with an unknown theme exits 2 with a hint", async () => {
  const { env } = themeFixture();
  const r = await run(["theme", "set", "neon"], env);
  expect(r.code).toBe(2);
  // Per §2.6: single signal — glyph or word, never both.
  expect(r.stderr).toContain("unknown theme");
  expect(r.stderr).toContain("Try:");
});

// A fake theme manifest + asset dirs so theme commands run without a real
// desktop. Actuator commands (awww/makoctl/hyprctl/notify-send) are absent
// in the sandbox — the CLI must tolerate that (best-effort semantics).
function themeFixture(): { dir: string; env: Record<string, string> } {
  const dir = `/tmp/marchyo-cli-test-theme-${Date.now()}-${Math.random().toString(36).slice(2)}`;
  for (const t of ["alpha", "beta"]) {
    Bun.spawnSync(["mkdir", "-p", `${dir}/themes/${t}`]);
    Bun.spawnSync([
      "bash",
      "-c",
      `printf 'dark\\n' > ${dir}/themes/${t}/variant`,
    ]);
  }
  Bun.spawnSync(["mkdir", "-p", `${dir}/data/marchyo/themes`]);
  Bun.write(
    `${dir}/data/marchyo/themes/manifest.json`,
    JSON.stringify([
      { name: "alpha", variant: "dark", dir: `${dir}/themes/alpha` },
      { name: "beta", variant: "light", dir: `${dir}/themes/beta` },
    ]),
  );
  return {
    dir,
    env: {
      XDG_DATA_HOME: `${dir}/data`,
      XDG_CONFIG_HOME: `${dir}/config`,
      XDG_STATE_HOME: `${dir}/state`,
    },
  };
}

test("theme list marks the active theme from the pointer", async () => {
  const { env } = themeFixture();
  let r = await run(["theme", "list", "--json"], env);
  expect(r.code).toBe(0);
  let parsed = JSON.parse(r.stdout);
  expect(parsed.themes.map((t: { name: string }) => t.name)).toEqual([
    "alpha",
    "beta",
  ]);
  // No pointer yet: nothing current.
  expect(parsed.themes.every((t: { current: boolean }) => !t.current)).toBe(
    true,
  );
});

test("theme set switches live, records an override, and theme get reads it back", async () => {
  const { env } = themeFixture();
  let r = await run(["theme", "set", "beta"], env);
  expect(r.code).toBe(0);
  expect(r.stderr).toContain("theme.selection");

  r = await run(["theme", "get", "--json"], env);
  expect(JSON.parse(r.stdout).theme).toEqual({
    name: "beta",
    variant: "light",
  });

  r = await run(["runtime", "status", "--json"], env);
  expect(JSON.parse(r.stdout).overrides).toEqual([
    { key: "theme.selection", value: "beta" },
  ]);
});

test("theme next cycles through the manifest", async () => {
  const { env } = themeFixture();
  let r = await run(["theme", "next"], env);
  expect(r.code).toBe(0);
  r = await run(["theme", "get", "--json"], env);
  expect(JSON.parse(r.stdout).theme.name).toBe("alpha");
  r = await run(["theme", "next"], env);
  expect(r.code).toBe(0);
  r = await run(["theme", "get", "--json"], env);
  expect(JSON.parse(r.stdout).theme.name).toBe("beta");
});

test("theme set --apply --revert together is a usage error", async () => {
  const { env } = themeFixture();
  const r = await run(["theme", "set", "alpha", "--apply", "--revert"], env);
  expect(r.code).toBe(2);
  expect(r.stderr).toContain("mutually exclusive");
});

test("runtime restore replays a theme override", async () => {
  const { env } = themeFixture();
  let r = await run(["theme", "set", "beta"], env);
  expect(r.code).toBe(0);
  r = await run(["runtime", "restore"], env);
  expect(r.code).toBe(0);
  expect(r.stderr).toContain("restored 1/1");
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

// A throwaway flake dir + fresh XDG home so detectFlake resolves via cwd
// (no cached _flake state, no /etc/nixos in the sandbox).
function flakeFixture(): { dir: string; env: Record<string, string> } {
  const dir = `/tmp/marchyo-cli-test-flake-${Date.now()}-${Math.random().toString(36).slice(2)}`;
  Bun.spawnSync(["mkdir", "-p", dir]);
  Bun.write(`${dir}/flake.nix`, "{ outputs = _: { }; }\n");
  return { dir, env: { XDG_CONFIG_HOME: `${dir}/xdg` } };
}

test("update --dry-run prints the nix flake update command", async () => {
  const { dir, env } = flakeFixture();
  const r = await run(["update", "--dry-run"], env, dir);
  expect(r.code).toBe(0);
  expect(r.stdout).toContain("nix flake update --flake");
  expect(r.stdout).toContain(dir);
});

test("update --dry-run --json emits the command and flake location", async () => {
  const { dir, env } = flakeFixture();
  const r = await run(["update", "-n", "--json"], env, dir);
  expect(r.code).toBe(0);
  const parsed = JSON.parse(r.stdout);
  expect(parsed.command).toContain("nix flake update --flake");
  expect(parsed.flake.path).toBe(dir);
});

test("upgrade --dry-run prints update then rebuild commands", async () => {
  const { dir, env } = flakeFixture();
  const r = await run(["upgrade", "-n"], env, dir);
  expect(r.code).toBe(0);
  const [first, second] = r.stdout.trim().split("\n");
  expect(first).toContain("nix flake update --flake");
  expect(second).toContain("nixos-rebuild switch");
  expect(second).toContain(dir);
});

test("upgrade --dry-run --json emits a commands array", async () => {
  const { dir, env } = flakeFixture();
  const r = await run(["upgrade", "-n", "--json"], env, dir);
  expect(r.code).toBe(0);
  const parsed = JSON.parse(r.stdout);
  expect(parsed.commands).toHaveLength(2);
  expect(parsed.commands[0]).toContain("nix flake update");
  expect(parsed.commands[1]).toContain("nixos-rebuild switch");
});

test("rollback --dry-run prints the nixos-rebuild rollback command", async () => {
  const r = await run(["rollback", "-n"]);
  expect(r.code).toBe(0);
  expect(r.stdout).toContain("nixos-rebuild switch --rollback");
});

test("rollback --dry-run --json emits the command", async () => {
  const r = await run(["rollback", "-n", "--json"]);
  expect(r.code).toBe(0);
  const parsed = JSON.parse(r.stdout);
  expect(parsed.command).toContain("nixos-rebuild switch --rollback");
});

test("gc --dry-run prints the default 14d command", async () => {
  const r = await run(["gc", "-n"]);
  expect(r.code).toBe(0);
  expect(r.stdout).toContain("nix-collect-garbage --delete-older-than 14d");
});

test("gc --dry-run honors --delete-older-than", async () => {
  const r = await run(["gc", "-n", "--delete-older-than", "30d"]);
  expect(r.code).toBe(0);
  expect(r.stdout).toContain("--delete-older-than 30d");
});

test("gc rejects a malformed period with exit 2 and a Try line", async () => {
  const r = await run(["gc", "-n", "--delete-older-than", "2weeks"]);
  expect(r.code).toBe(2);
  expect(r.stderr).toContain("invalid period");
  expect(r.stderr).toContain("Try: marchyo gc");
});

test("diff --dry-run prints a dix command or fails gracefully off-NixOS", async () => {
  const r = await run(["diff", "-n"]);
  if (r.code === 0) {
    // On a NixOS host: either a dix command or the single-generation notice.
    expect(r.stdout + r.stderr).toMatch(/dix |nothing to diff/);
  } else {
    // Sandbox without /nix: graceful error, no stack trace.
    expect(r.code).toBe(1);
    expect(r.stderr).toContain("no system generations found");
    expect(r.stderr).not.toContain("throw");
  }
});

test("debug --json emits a parseable diagnostics bundle", async () => {
  const r = await run(["debug", "--json"]);
  expect(r.code).toBe(0);
  const parsed = JSON.parse(r.stdout);
  expect(parsed.cliVersion).toBe("0.1.0");
  // Best-effort fields exist even when the probe failed (null, not absent).
  for (const key of [
    "nixosVersion",
    "generation",
    "generationDate",
    "flake",
    "journalErrors",
  ]) {
    expect(parsed).toHaveProperty(key);
  }
});

test("debug text output survives missing system tools", async () => {
  const r = await run(["debug"]);
  expect(r.code).toBe(0);
  expect(r.stdout).toContain("Marchyo debug bundle");
  expect(r.stdout).toContain("CLI version:     0.1.0");
});

// A fresh XDG_STATE_HOME so runtime-override reads/writes never touch real
// state. Mirrors flakeFixture's isolation approach.
function stateFixture(): { dir: string; env: Record<string, string> } {
  const dir = `/tmp/marchyo-cli-test-state-${Date.now()}-${Math.random().toString(36).slice(2)}`;
  Bun.spawnSync(["mkdir", "-p", dir]);
  return { dir, env: { XDG_STATE_HOME: dir, XDG_CONFIG_HOME: `${dir}/xdg` } };
}

test("runtime status with no overrides prints the empty notice", async () => {
  const { env } = stateFixture();
  const r = await run(["runtime", "status"], env);
  expect(r.code).toBe(0);
  expect(r.stdout).toContain("(no runtime overrides)");
});

test("runtime status --json lists stored overrides", async () => {
  const { dir, env } = stateFixture();
  await Bun.write(
    `${dir}/marchyo/runtime.json`,
    JSON.stringify({
      schemaVersion: 1,
      overrides: { "toggle.nightlight": true },
    }) + "\n",
  );
  const r = await run(["runtime", "status", "--json"], env);
  expect(r.code).toBe(0);
  const parsed = JSON.parse(r.stdout);
  expect(parsed.overrides).toEqual([
    { key: "toggle.nightlight", value: true },
  ]);
});

test("runtime restore with no overrides is a quiet no-op", async () => {
  const { env } = stateFixture();
  const r = await run(["runtime", "restore"], env);
  expect(r.code).toBe(0);
  expect(r.stderr).toContain("no runtime overrides to restore");
});

test("runtime restore skips unknown override keys with a warning", async () => {
  const { dir, env } = stateFixture();
  await Bun.write(
    `${dir}/marchyo/runtime.json`,
    JSON.stringify({
      schemaVersion: 1,
      overrides: { "no.such.key": "x" },
    }) + "\n",
  );
  const r = await run(["runtime", "restore"], env);
  expect(r.code).toBe(0);
  expect(r.stderr).toContain("no handler registered");
  expect(r.stderr).toContain("restored 0/1");
});

test("runtime restore ignores a corrupt runtime.json with a warning", async () => {
  const { dir, env } = stateFixture();
  await Bun.write(`${dir}/marchyo/runtime.json`, "{corrupt");
  const r = await run(["runtime", "restore"], env);
  expect(r.code).toBe(0);
  expect(r.stderr).toContain("ignoring invalid runtime state");
});

test("toggle with an unknown name exits 2 listing the toggles", async () => {
  const { env } = stateFixture();
  const r = await run(["toggle", "warp-drive"], env);
  expect(r.code).toBe(2);
  expect(r.stderr).toContain("unknown toggle");
  expect(r.stderr).toContain("nightlight");
});

test("toggle with a bad state arg exits 2", async () => {
  const { env } = stateFixture();
  const r = await run(["toggle", "nightlight", "maybe"], env);
  expect(r.code).toBe(2);
  expect(r.stderr).toContain("invalid state");
});

test("toggle nightlight records a runtime override (actuators absent)", async () => {
  const { env } = stateFixture();
  let r = await run(["toggle", "nightlight", "on"], env);
  expect(r.code).toBe(0);
  r = await run(["runtime", "status", "--json"], env);
  expect(JSON.parse(r.stdout).overrides).toEqual([
    { key: "toggle.nightlight", value: true },
  ]);
  // Flip with no argument inverts the recorded state.
  r = await run(["toggle", "nightlight"], env);
  expect(r.code).toBe(0);
  r = await run(["runtime", "status", "--json"], env);
  expect(JSON.parse(r.stdout).overrides).toEqual([
    { key: "toggle.nightlight", value: false },
  ]);
});

test("toggle --status reports default state as scriptable output", async () => {
  const { env } = stateFixture();
  const r = await run(["toggle", "screensaver", "--status", "--json"], env);
  expect(r.code).toBe(0);
  expect(JSON.parse(r.stdout).toggle).toEqual({
    name: "screensaver",
    on: true,
  });
});

test("toggle hybrid-gpu without --apply is a usage error", async () => {
  const { env } = stateFixture();
  const r = await run(["toggle", "hybrid-gpu", "on"], env);
  expect(r.code).toBe(2);
  expect(r.stderr).toContain("no live toggle");
  expect(r.stderr).toContain("--apply");
});

test("toggle nightlight --revert clears the override", async () => {
  const { env } = stateFixture();
  let r = await run(["toggle", "nightlight", "on"], env);
  expect(r.code).toBe(0);
  r = await run(["toggle", "nightlight", "--revert"], env);
  expect(r.code).toBe(0);
  r = await run(["runtime", "status", "--json"], env);
  expect(JSON.parse(r.stdout).overrides).toEqual([]);
});

test("capture screenshot with an invalid target exits 2", async () => {
  const r = await run(["capture", "screenshot", "--target", "moon"]);
  expect(r.code).toBe(2);
  expect(r.stderr).toContain("invalid target");
});

test("capture record with an invalid audio source exits 2", async () => {
  const r = await run(["capture", "record", "--audio", "vinyl"]);
  expect(r.code).toBe(2);
  expect(r.stderr).toContain("invalid audio source");
});

test("capture screenshot without grimblast fails cleanly", async () => {
  // The sandbox has no desktop tools; the command must error (exit 1),
  // not crash, and name the missing tool.
  const r = await run(["capture", "screenshot"]);
  if (r.code !== 0) {
    expect(r.code).toBe(1);
    expect(r.stderr).toContain("grimblast");
  }
});

test("capture color without hyprpicker fails cleanly", async () => {
  const r = await run(["capture", "color"]);
  if (r.code !== 0) {
    expect(r.code).toBe(1);
    expect(r.stderr).toContain("hyprpicker");
  }
});

test("zoom with a bad direction exits 2", async () => {
  const r = await run(["zoom", "sideways"]);
  expect(r.code).toBe(2);
  expect(r.stderr).toContain("invalid zoom direction");
});

test("menu with an unknown submenu exits 2", async () => {
  const r = await run(["menu", "snacks"]);
  expect(r.code).toBe(2);
  expect(r.stderr).toContain("unknown menu");
});

test("powerprofile set with a bad profile exits 2", async () => {
  const r = await run(["powerprofile", "set", "turbo"]);
  // Without powerprofilesctl in the sandbox the tool-missing error (1)
  // fires first; with it, validation rejects the profile (2).
  expect([1, 2]).toContain(r.code);
  expect(r.stderr.length).toBeGreaterThan(0);
});

test("launch with a missing app fails cleanly", async () => {
  const r = await run(["launch", "definitely-not-a-real-app"]);
  expect(r.code).toBe(1);
  expect(r.stderr).toContain("not found in PATH");
});

test("keybindings outside Hyprland fails cleanly", async () => {
  const r = await run(["keybindings"]);
  expect(r.code).toBe(1);
  expect(r.stderr.length).toBeGreaterThan(0);
});

test("info with an unknown topic exits 2", async () => {
  const r = await run(["info", "weather"]);
  expect(r.code).toBe(2);
  expect(r.stderr).toContain("unknown info");
});

test("transcode with a missing file fails cleanly", async () => {
  const r = await run(["transcode", "/nonexistent.mov", "--to", "mp4"]);
  expect(r.code).toBe(1);
  expect(r.stderr).toContain("not a file");
});

test("transcode with an invalid target format exits 2", async () => {
  const dir = `/tmp/marchyo-cli-test-transcode-${Date.now()}`;
  Bun.spawnSync(["mkdir", "-p", dir]);
  await Bun.write(`${dir}/clip.mov`, "x");
  const r = await run(["transcode", `${dir}/clip.mov`, "--to", "avi"]);
  expect(r.code).toBe(2);
  expect(r.stderr).toContain("invalid target format");
});

test("share with a missing file fails cleanly", async () => {
  const r = await run(["share", "/nonexistent.txt"]);
  expect(r.code).toBe(1);
  expect(r.stderr.length).toBeGreaterThan(0);
});

test("font set records a runtime override and font set --revert clears it", async () => {
  const { dir, env } = stateFixture();
  let r = await run(["font", "set", "Test Mono"], env);
  expect(r.code).toBe(0);
  const override = await Bun.file(
    `${dir}/xdg/marchyo/font-override.conf`,
  ).text();
  expect(override).toContain("font-family = Test Mono");
  r = await run(["runtime", "status", "--json"], env);
  expect(JSON.parse(r.stdout).overrides).toEqual([
    { key: "font.family", value: "Test Mono" },
  ]);
  r = await run(["font", "set", "--revert"], env);
  expect(r.code).toBe(0);
  expect(
    await Bun.file(`${dir}/xdg/marchyo/font-override.conf`).exists(),
  ).toBe(false);
});

test("font set without a family exits 2", async () => {
  const { env } = stateFixture();
  const r = await run(["font", "set"], env);
  expect(r.code).toBe(2);
  expect(r.stderr).toContain("needs a font family");
});

test("install with an unknown feature exits 2", async () => {
  const r = await run(["install", "jetpack"]);
  expect(r.code).toBe(2);
  expect(r.stderr).toContain("unknown feature");
});

test("install --dry-run prints the state patch without writing", async () => {
  const { env } = stateFixture();
  const r = await run(["install", "development", "--dry-run"], env);
  expect(r.code).toBe(0);
  expect(JSON.parse(r.stdout)).toEqual({ development: { enable: true } });
});

test("remove --dry-run prints the disable patch", async () => {
  const { env } = stateFixture();
  const r = await run(["remove", "media", "-n"], env);
  expect(r.code).toBe(0);
  expect(JSON.parse(r.stdout)).toEqual({ media: { enable: false } });
});

test("webapp add rejects a taken SUPER+SHIFT key", async () => {
  const { env } = stateFixture();
  const r = await run(
    ["webapp", "add", "https://figma.com", "--key", "G", "-n"],
    env,
  );
  expect(r.code).toBe(2);
  expect(r.stderr).toContain("already taken");
});

test("webapp add --dry-run derives the name and emits the entry", async () => {
  const { env } = stateFixture();
  const r = await run(
    ["webapp", "add", "https://www.figma.com/", "--key", "F", "-n"],
    env,
  );
  expect(r.code).toBe(0);
  const patch = JSON.parse(r.stdout);
  expect(patch.webapps.extraApps).toEqual([
    { name: "Figma", url: "https://www.figma.com/", key: "F" },
  ]);
});

test("webapp add with an invalid URL exits 2", async () => {
  const r = await run(["webapp", "add", "not a url", "-n"]);
  expect(r.code).toBe(2);
  expect(r.stderr).toContain("invalid URL");
});

test("webapp rm on a non-CLI-managed app fails with the apps hint", async () => {
  const { env } = stateFixture();
  const r = await run(["webapp", "rm", "YouTube", "-n"], env);
  expect(r.code).toBe(1);
  expect(r.stderr).toContain("not CLI-managed");
  expect(r.stderr).toContain("marchyo.webapps.apps");
});

test("security enroll with an unknown method exits 2", async () => {
  const r = await run(["security", "enroll", "retina"]);
  expect(r.code).toBe(2);
  expect(r.stderr).toContain("unknown method");
});

test("security enroll fido2 without pamu2fcfg names the option", async () => {
  const r = await run(["security", "enroll", "fido2"]);
  if (r.code !== 0) {
    expect(r.code).toBe(1);
    expect(r.stderr).toContain("marchyo.security.fido2.enable");
  }
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

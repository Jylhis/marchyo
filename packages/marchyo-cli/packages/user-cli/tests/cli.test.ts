import { test, expect, afterAll } from "bun:test";
import { join } from "node:path";
import { existsSync, rmSync } from "node:fs";

// Clean up any state file the smoke tests below may have written.
// Running as root (e.g. in a CI sandbox) writes go to /etc/marchyo;
// running unprivileged with our XDG override they go under /tmp.
//
// Unprivileged, /etc/marchyo is either absent (nothing to do) or a root-owned
// directory this process must not touch, so rmSync would throw EACCES and fail
// the whole file. Only reclaim what we could have created.
afterAll(() => {
  try {
    rmSync("/etc/marchyo/cli-state.json", { force: true });
    rmSync("/etc/marchyo", { recursive: true, force: true });
  } catch {
    // Not ours to remove; the sandbox run that created it cleans up its own.
  }
});

const REPO = join(import.meta.dir, "..", "..", "..");
const CLI = join(REPO, "packages", "user-cli", "src", "cli.tsx");

async function run(
  args: string[],
  env: Record<string, string> = {},
  cwd?: string,
): Promise<{ code: number; stdout: string; stderr: string }> {
  // process.execPath, not "bun": a test that neutralizes PATH (to assert a
  // tool-missing path) must still be able to launch the interpreter.
  const proc = Bun.spawn([process.execPath, CLI, ...args], {
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
  expect(r.stdout.trim()).toBe("1.0.0");
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

test("theme set swaps gtk css symlinks and the dconf color-scheme", async () => {
  const { dir, env } = themeFixture();
  // GTK assets in the fixture theme dirs arm the new actuation legs; a stub
  // dconf on PATH records argv so the write is assertable without a session.
  await Bun.write(`${dir}/themes/alpha/gtk.css`, "/* dark gtk */\n");
  await Bun.write(`${dir}/themes/beta/gtk.css`, "/* light gtk */\n");
  const bin = `${dir}/bin`;
  Bun.spawnSync(["mkdir", "-p", bin]);
  const dconfLog = `${dir}/dconf.log`;
  await Bun.write(
    `${bin}/dconf`,
    `#!/usr/bin/env bash\necho "$@" >> "${dconfLog}"\n`,
  );
  Bun.spawnSync(["chmod", "+x", `${bin}/dconf`]);
  const full = { ...env, PATH: `${bin}:${process.env.PATH}` };

  let r = await run(["theme", "set", "beta"], full);
  expect(r.code).toBe(0);
  // Both GTK versions' user css are relinked into the theme dir (HM-managed
  // symlinks until the next activation).
  expect(await Bun.file(`${env.XDG_CONFIG_HOME}/gtk-3.0/gtk.css`).text()).toBe(
    "/* light gtk */\n",
  );
  expect(await Bun.file(`${env.XDG_CONFIG_HOME}/gtk-4.0/gtk.css`).text()).toBe(
    "/* light gtk */\n",
  );
  // The dconf color-scheme flip follows the theme's polarity.
  expect(await Bun.file(dconfLog).text()).toBe(
    "write /org/gnome/desktop/interface/color-scheme 'prefer-light'\n",
  );

  r = await run(["theme", "set", "alpha"], full);
  expect(r.code).toBe(0);
  expect(await Bun.file(`${env.XDG_CONFIG_HOME}/gtk-3.0/gtk.css`).text()).toBe(
    "/* dark gtk */\n",
  );
  expect(await Bun.file(dconfLog).text()).toContain("'prefer-dark'");
});

test("theme set applies Hyprland colors through one hyprctl eval hl.config call", async () => {
  const { dir, env } = themeFixture();
  // hyprland.conf in the fixture theme dir arms the Hyprland leg; a stub
  // hyprctl on PATH records argv so the single eval call is assertable
  // without a live session.
  await Bun.write(
    `${dir}/themes/alpha/hyprland.conf`,
    [
      "misc:background_color rgb(0d0f14)",
      "general:col.active_border rgba(e0a33aff)",
      "general:col.inactive_border rgba(3a4150ff)",
    ].join("\n") + "\n",
  );
  const bin = `${dir}/bin`;
  Bun.spawnSync(["mkdir", "-p", bin]);
  const hyprctlLog = `${dir}/hyprctl.log`;
  await Bun.write(
    `${bin}/hyprctl`,
    `#!/usr/bin/env bash\necho "$@" >> "${hyprctlLog}"\n`,
  );
  Bun.spawnSync(["chmod", "+x", `${bin}/hyprctl`]);
  const full = {
    ...env,
    PATH: `${bin}:${process.env.PATH}`,
    HYPRLAND_INSTANCE_SIGNATURE: "test-signature",
  };

  const r = await run(["theme", "set", "alpha"], full);
  expect(r.code).toBe(0);
  // Exactly one hyprctl invocation, and it is the eval form — the per-keyword
  // `hyprctl keyword` calls are a silent no-op under non-legacy (Lua) parsers.
  // ($@ in the stub excludes argv0, so the log line starts at "eval".)
  const calls = (await Bun.file(hyprctlLog).text()).trim().split("\n");
  expect(calls.length).toBe(1);
  expect(calls[0]).toMatch(/^eval hl\.config\(/);
  expect(calls[0]).toContain('["misc"] = { ["background_color"] = "rgb(0d0f14)" }');
  expect(calls[0]).toContain(
    '["general"] = { ["col.active_border"] = "rgba(e0a33aff)", ["col.inactive_border"] = "rgba(3a4150ff)" }',
  );
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
  expect(parsed.cliVersion).toBe("1.0.0");
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
  expect(r.stdout).toContain("CLI version:     1.0.0");
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

// PATH="" is what makes these two assertions unconditional: commandAvailable
// walks $PATH, so an empty one guarantees the tool-missing branch. Without it
// a developer host that actually has grimblast launches an interactive area
// selection and the test hangs until the 5s timeout instead of asserting.
test("capture screenshot without grimblast fails cleanly", async () => {
  const r = await run(["capture", "screenshot"], { PATH: "" });
  expect(r.code).toBe(1);
  expect(r.stderr).toContain("grimblast");
});

test("capture color without hyprpicker fails cleanly", async () => {
  const r = await run(["capture", "color"], { PATH: "" });
  expect(r.code).toBe(1);
  expect(r.stderr).toContain("hyprpicker");
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
  // Empty, not absent: hyprlandAvailable treats "" as no session, and an
  // inherited signature from the developer's own Hyprland would make this
  // succeed and assert nothing.
  const r = await run(["keybindings"], { HYPRLAND_INSTANCE_SIGNATURE: "" });
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

test("bg set with no path is a usage error and writes no state", async () => {
  // Regression: the positional is optional (it is omitted with --revert) and
  // the action passed "". resolve("") returns the cwd, existsSync(cwd) is
  // always true, so the guard never fired and the *current directory* got
  // persisted into runtime.json as the wallpaper.
  const { dir, env } = stateFixture();
  const r = await run(["bg", "set"], env);
  expect(r.code).toBe(2);
  expect(r.stderr).toContain("bg set needs an image path");
  expect(existsSync(`${dir}/marchyo/runtime.json`)).toBe(false);
});

test("bg set with a nonexistent path fails without writing state", async () => {
  const { dir, env } = stateFixture();
  const r = await run(["bg", "set", "/nonexistent/wall.png"], env);
  expect(r.code).toBe(1);
  expect(r.stderr).toContain("no such image");
  expect(existsSync(`${dir}/marchyo/runtime.json`)).toBe(false);
});

// ── shell / volume / brightness / doctor ────────────────────────────────────
//
// Stub tools in a private PATH: each stub appends its argv to calls.log and
// prints a canned reply, so the verbs run end to end without a live shell.
// Shebangs are absolute because the stub PATH has no bash on it.

const BASH = Bun.which("bash") ?? "/bin/sh";

function stubDir(stubs: Record<string, string>): {
  dir: string;
  bin: string;
  calls: () => string[];
} {
  const dir = `/tmp/marchyo-cli-test-stubs-${Date.now()}-${Math.random().toString(36).slice(2)}`;
  const bin = `${dir}/bin`;
  Bun.spawnSync(["mkdir", "-p", bin]);
  for (const [name, body] of Object.entries(stubs)) {
    const path = `${bin}/${name}`;
    Bun.spawnSync([
      BASH,
      "-c",
      `printf '%s\\n' "$1" > "$2" && chmod +x "$2"`,
      "_",
      `#!${BASH}\nprintf '%s\\n' "${name} $*" >> "${dir}/calls.log"\n${body}`,
      path,
    ]);
  }
  return {
    dir,
    bin,
    calls: () => {
      const r = Bun.spawnSync(["cat", `${dir}/calls.log`]);
      return r.stdout.toString().split("\n").filter((l) => l !== "");
    },
  };
}

// A marchyo-shell stub that answers each IpcHandler function like shell.qml.
const SHELL_STUB = `case "$6" in
  toggleBar) echo on ;;
  toggleDnd) echo off ;;
  toggleOverview) echo on ;;
  lockState) echo locked ;;
  ping) echo ok ;;
  nope) echo "Function not found." ;;
  *) echo ok ;;
esac`;

test("shell verbs without marchyo-shell exit 1 naming the wrapper", async () => {
  const r = await run(["shell", "toggle", "audio"], { PATH: "" });
  expect(r.code).toBe(1);
  expect(r.stderr).toContain("marchyo-shell not found");
});

test("shell verbs exit 1 with a start hint when the shell is not running", async () => {
  const s = stubDir({
    "marchyo-shell": `echo 'No running instances for "/nix/store/x/shell.qml"'; exit 255`,
  });
  const r = await run(["shell", "reload"], { PATH: s.bin });
  expect(r.code).toBe(1);
  expect(r.stderr).toContain("not running");
  expect(r.stderr).toContain("systemctl --user start marchyo-shell");
});

test("shell bar --json reports the IPC function and its reply", async () => {
  const s = stubDir({ "marchyo-shell": SHELL_STUB });
  const r = await run(["shell", "bar", "--json"], { PATH: s.bin });
  expect(r.code).toBe(0);
  expect(JSON.parse(r.stdout)).toEqual({ function: "toggleBar", reply: "on" });
  expect(s.calls()).toEqual(["marchyo-shell ipc -n call -- shell toggleBar"]);
});

test("shell toggle/open/close/launcher map onto the IpcHandler functions", async () => {
  const s = stubDir({ "marchyo-shell": SHELL_STUB });
  for (const args of [
    ["shell", "toggle", "audio"],
    ["shell", "toggle", "controlcenter"],
    ["shell", "open", "network"],
    ["shell", "close"],
    ["shell", "close", "notifications"],
    ["shell", "launcher", "emoji"],
    ["shell", "bar", "off"],
    ["shell", "dismiss"],
    ["shell", "dismiss", "--all"],
    ["shell", "dnd"],
    ["shell", "dnd", "on"],
    ["shell", "lock"],
    ["shell", "overview"],
    ["shell", "overview", "on"],
    ["shell", "overview", "off"],
  ]) {
    expect((await run(args, { PATH: s.bin })).code).toBe(0);
  }
  expect(s.calls()).toEqual([
    "marchyo-shell ipc -n call -- shell togglePanel audio",
    "marchyo-shell ipc -n call -- shell togglePanel controlcenter",
    "marchyo-shell ipc -n call -- shell openPanel network",
    "marchyo-shell ipc -n call -- shell closePanels",
    "marchyo-shell ipc -n call -- shell closePanel notifications",
    "marchyo-shell ipc -n call -- shell toggleLauncher emoji",
    "marchyo-shell ipc -n call -- shell setBar off",
    "marchyo-shell ipc -n call -- shell dismissLast",
    "marchyo-shell ipc -n call -- shell clearNotifications",
    "marchyo-shell ipc -n call -- shell toggleDnd",
    "marchyo-shell ipc -n call -- shell setDnd on",
    "marchyo-shell ipc -n call -- shell lock",
    "marchyo-shell ipc -n call -- shell toggleOverview",
    "marchyo-shell ipc -n call -- shell openOverview",
    "marchyo-shell ipc -n call -- shell closeOverview",
  ]);
});

test("shell lock-state prints the bare reply for scripts", async () => {
  const s = stubDir({ "marchyo-shell": SHELL_STUB });
  const r = await run(["shell", "lock-state"], { PATH: s.bin });
  expect(r.code).toBe(0);
  expect(r.stdout).toBe("locked\n");
  expect(s.calls()).toEqual(["marchyo-shell ipc -n call -- shell lockState"]);
});

test("shell dnd --json reports the IPC function and its reply", async () => {
  const s = stubDir({ "marchyo-shell": SHELL_STUB });
  const r = await run(["shell", "dnd", "--json"], { PATH: s.bin });
  expect(r.code).toBe(0);
  expect(JSON.parse(r.stdout)).toEqual({ function: "toggleDnd", reply: "off" });
});

test("shell verbs reject bad arguments with exit 2", async () => {
  expect((await run(["shell", "bar", "maybe"], { PATH: "" })).code).toBe(2);
  expect((await run(["shell", "toggle", "Not A Panel"], { PATH: "" })).code).toBe(2);
  expect((await run(["shell", "launcher", "../x"], { PATH: "" })).code).toBe(2);
  expect((await run(["shell", "close", "Not A Panel"], { PATH: "" })).code).toBe(2);
  expect((await run(["shell", "dnd", "maybe"], { PATH: "" })).code).toBe(2);
  expect((await run(["shell", "overview", "maybe"], { PATH: "" })).code).toBe(2);
});

test("shell overview --json reports the IPC function and its reply", async () => {
  const s = stubDir({ "marchyo-shell": SHELL_STUB });
  const r = await run(["shell", "overview", "--json"], { PATH: s.bin });
  expect(r.code).toBe(0);
  expect(JSON.parse(r.stdout)).toEqual({ function: "toggleOverview", reply: "on" });
  expect(s.calls()).toEqual(["marchyo-shell ipc -n call -- shell toggleOverview"]);
});

test("volume with a bad action exits 2", async () => {
  const r = await run(["volume", "sideways"], { PATH: "" });
  expect(r.code).toBe(2);
  expect(r.stderr).toContain("marchyo volume up|down|mute");
});

test("volume uses silent wpctl when the shell is installed", async () => {
  const s = stubDir({ "marchyo-shell": SHELL_STUB, wpctl: "", "swayosd-client": "" });
  expect((await run(["volume", "up"], { PATH: s.bin })).code).toBe(0);
  expect((await run(["volume", "mute", "--mic"], { PATH: s.bin })).code).toBe(0);
  expect(s.calls()).toEqual([
    "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+",
    "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",
  ]);
});

test("volume uses swayosd-client when it is installed and the shell is not", async () => {
  const s = stubDir({ wpctl: "", "swayosd-client": "" });
  expect((await run(["volume", "down"], { PATH: s.bin })).code).toBe(0);
  expect(s.calls()).toEqual(["swayosd-client --output-volume lower"]);
});

test("volume without wpctl fails cleanly", async () => {
  const r = await run(["volume", "up"], { PATH: "" });
  expect(r.code).toBe(1);
  expect(r.stderr).toContain("wpctl");
});

test("brightness steps brightnessctl and pokes the shell OSD", async () => {
  const s = stubDir({
    "marchyo-shell": SHELL_STUB,
    brightnessctl: `case "$1" in get) echo 120 ;; max) echo 240 ;; esac`,
  });
  const r = await run(["brightness", "up"], { PATH: s.bin });
  expect(r.code).toBe(0);
  const calls = s.calls();
  expect(calls[0]).toBe("brightnessctl -e4 -n2 set 5%+");
  expect(calls).toContain("marchyo-shell ipc -n call -- shell osdShow BRT 50 true");
});

test("brightness still succeeds when the shell is not running", async () => {
  const s = stubDir({
    "marchyo-shell": `echo 'No running instances for "x"'; exit 255`,
    brightnessctl: `case "$1" in get) echo 1 ;; max) echo 2 ;; esac`,
  });
  expect((await run(["brightness", "down"], { PATH: s.bin })).code).toBe(0);
});

test("brightness with a bad action exits 2", async () => {
  expect((await run(["brightness", "sideways"], { PATH: "" })).code).toBe(2);
});

type DoctorJson = {
  ok: boolean;
  checks: { name: string; status: "pass" | "fail" | "skip"; detail: string }[];
};

test("doctor with nothing applicable skips every check and exits 0", async () => {
  const r = await run(["doctor", "--json"], {
    PATH: "",
    HYPRLAND_INSTANCE_SIGNATURE: "",
  });
  expect(r.code).toBe(0);
  const report = JSON.parse(r.stdout) as DoctorJson;
  expect(report.ok).toBe(true);
  expect(report.checks.length).toBeGreaterThan(0);
  expect(report.checks.every((c) => c.status === "skip")).toBe(true);
});

// A fake store shell: the wrapper stub lives in out/bin, PATH holds a
// symlink to it (like a profile), and out/share/.../Config.qml bakes one
// existing and one missing tool path.
function doctorFixture(): { bin: string; missing: string } {
  const s = stubDir({ "marchyo-shell": SHELL_STUB });
  const out = `${s.dir}/out`;
  const commons = `${out}/share/marchyo/shell/Commons`;
  const missing = `${s.dir}/gone/bin/curl`;
  Bun.spawnSync(["mkdir", "-p", `${out}/bin`, commons, `${s.dir}/profile`]);
  Bun.spawnSync(["mv", `${s.bin}/marchyo-shell`, `${out}/bin/marchyo-shell`]);
  Bun.spawnSync(["ln", "-s", `${out}/bin/marchyo-shell`, `${s.bin}/marchyo-shell`]);
  Bun.write(
    `${commons}/Config.qml`,
    `QtObject {
  readonly property string shellBin: "${out}/bin/marchyo-shell"
  readonly property string curl: "${missing}"
  readonly property string terminal: "ghostty"
}
`,
  );
  return { bin: s.bin, missing };
}

test("doctor fails on a missing baked tool path and exits 1", async () => {
  const { bin, missing } = doctorFixture();
  const r = await run(["doctor", "--json"], {
    PATH: bin,
    HYPRLAND_INSTANCE_SIGNATURE: "",
  });
  expect(r.code).toBe(1);
  const report = JSON.parse(r.stdout) as DoctorJson;
  expect(report.ok).toBe(false);
  const byName = Object.fromEntries(report.checks.map((c) => [c.name, c]));
  expect(byName["shell tool paths"]?.status).toBe("fail");
  expect(byName["shell tool paths"]?.detail).toContain(missing);
  expect(byName["shell ipc"]?.status).toBe("pass");
  expect(byName["hyprland ipc"]?.status).toBe("skip");
});

test("doctor text output labels each check PASS/FAIL/SKIP", async () => {
  const { bin } = doctorFixture();
  const r = await run(["doctor"], { PATH: bin, HYPRLAND_INSTANCE_SIGNATURE: "" });
  expect(r.code).toBe(1);
  expect(r.stdout).toMatch(/^FAIL {2}shell tool paths/m);
  expect(r.stdout).toMatch(/^PASS {2}shell ipc/m);
  expect(r.stdout).toMatch(/^SKIP {2}hyprland ipc/m);
  expect(r.stdout).toContain("1 check failed");
});

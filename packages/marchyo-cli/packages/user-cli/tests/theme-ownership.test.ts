import { afterAll, expect, test } from "bun:test";
import {
  chmodSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const roots: string[] = [];
afterAll(() => {
  for (const root of roots) rmSync(root, { recursive: true, force: true });
});

function fixture(defaultVariant: "dark" | "light" = "dark") {
  const root = mkdtempSync(join(tmpdir(), "marchyo-theme-owner-"));
  roots.push(root);
  const env = {
    ...process.env,
    HOME: root,
    XDG_CONFIG_HOME: join(root, "config"),
    XDG_DATA_HOME: join(root, "data"),
    XDG_STATE_HOME: join(root, "state"),
    XDG_RUNTIME_DIR: join(root, "run"),
    MARCHYO_GREETER_THEME_DIR: join(root, "greeter"),
    HYPRLAND_INSTANCE_SIGNATURE: "",
    PATH: join(root, "bin"),
    DCONF_RESULT: "0",
    NO_COLOR: "1",
  };
  const entries = (["dark", "light"] as const).map((variant) => {
    const dir = join(root, variant);
    mkdirSync(dir);
    writeFileSync(join(dir, "gtk.css"), variant);
    writeFileSync(join(dir, "btop.theme"), variant);
    return { name: `jylhis-${variant}`, variant, dir };
  });
  const manifest = join(env.XDG_DATA_HOME, "marchyo/themes/manifest.json");
  mkdirSync(join(manifest, ".."), { recursive: true });
  writeFileSync(
    manifest,
    JSON.stringify({
      themes: entries,
      defaultTheme: entries.find((entry) => entry.variant === defaultVariant),
    }),
  );
  mkdirSync(env.PATH);
  const dconf = join(env.PATH, "dconf");
  writeFileSync(
    dconf,
    `#!${process.execPath}
if (process.env.DCONF_RESULT !== "0") process.exit(Number(process.env.DCONF_RESULT));
await Bun.write(process.env.HOME + "/preference", process.argv.at(-1));
`,
  );
  chmodSync(dconf, 0o755);
  const state = join(env.XDG_STATE_HOME, "marchyo/runtime.json");
  const pointer = join(env.XDG_CONFIG_HOME, "marchyo/current-theme");
  const run = async (args: string[]) => {
    const proc = Bun.spawn(
      [process.execPath, join(import.meta.dir, "../src/cli.tsx"), ...args],
      {
        env,
        stdout: "pipe",
        stderr: "pipe",
      },
    );
    const [code, stderr] = await Promise.all([
      proc.exited,
      new Response(proc.stderr).text(),
    ]);
    return { code, stderr };
  };
  return { root, env, manifest, state, pointer, run };
}

for (const variant of ["dark", "light"] as const) {
  test(`restore initializes the ${variant} default without an override`, async () => {
    const f = fixture(variant);
    for (let attempt = 0; attempt < 2; attempt++) {
      expect((await f.run(["runtime", "restore"])).code).toBe(0);
      expect(realpathSync(f.pointer)).toBe(join(f.root, variant));
      expect(readFileSync(join(f.root, "preference"), "utf8")).toBe(
        `'prefer-${variant}'`,
      );
      expect(
        readFileSync(
          join(f.env.XDG_CONFIG_HOME, "btop/themes/marchyo.theme"),
          "utf8",
        ),
      ).toBe(variant);
    }
  });
}

test("a saved light theme survives restoring a dark default", async () => {
  const f = fixture();
  expect((await f.run(["theme", "set", "light"])).code).toBe(0);
  expect((await f.run(["runtime", "restore"])).code).toBe(0);
  expect(realpathSync(f.pointer)).toBe(join(f.root, "light"));
  expect(readFileSync(join(f.root, "preference"), "utf8")).toBe(
    "'prefer-light'",
  );
  expect(
    JSON.parse(readFileSync(f.state, "utf8")).overrides["theme.selection"],
  ).toBe("jylhis-light");
});

for (const failure of ["missing", "exit"] as const) {
  test(`a ${failure} dconf preserves the previous selection on switch and revert`, async () => {
    const f = fixture();
    expect((await f.run(["theme", "set", "light"])).code).toBe(0);
    const before = readFileSync(f.state, "utf8");
    if (failure === "missing") rmSync(join(f.env.PATH, "dconf"));
    else f.env.DCONF_RESULT = "1";
    for (const args of [
      ["theme", "set", "dark"],
      ["theme", "set", "dark", "--revert"],
    ]) {
      const result = await f.run(args);
      expect(result.code).not.toBe(0);
      expect(result.stderr).toContain("Cannot set the desktop preference");
      expect(realpathSync(f.pointer)).toBe(join(f.root, "light"));
      expect(readFileSync(f.state, "utf8")).toBe(before);
    }
  });
}

test("restore reports theme failure while restoring independent overrides", async () => {
  const f = fixture();
  expect((await f.run(["theme", "set", "light"])).code).toBe(0);
  const state = JSON.parse(readFileSync(f.state, "utf8"));
  state.overrides["theme.selection"] = "removed-theme";
  state.overrides["appearance.barPosition"] = "bottom";
  writeFileSync(f.state, JSON.stringify(state));
  const result = await f.run(["runtime", "restore"]);
  expect(result.code).toBe(1);
  expect(result.stderr).toContain("not in the manifest");
  expect(result.stderr).toContain("restored 1/2");
  expect(
    JSON.parse(
      readFileSync(
        join(f.env.XDG_STATE_HOME, "marchyo/shell/style.json"),
        "utf8",
      ),
    ).barPosition,
  ).toBe("bottom");
  expect(realpathSync(f.pointer)).toBe(join(f.root, "light"));
});

test("legacy manifests resolve the default through the declarative pointer", async () => {
  const f = fixture("light");
  const manifest = JSON.parse(readFileSync(f.manifest, "utf8"));
  delete manifest.defaultTheme;
  writeFileSync(f.manifest, JSON.stringify(manifest));
  const profile = join(
    f.env.XDG_STATE_HOME,
    "nix/profiles/home-manager/home-files/.config/marchyo",
  );
  mkdirSync(profile, { recursive: true });
  symlinkSync(join(f.root, "light"), join(profile, "current-theme"));
  expect((await f.run(["runtime", "restore"])).code).toBe(0);
  expect(realpathSync(f.pointer)).toBe(join(f.root, "light"));
});

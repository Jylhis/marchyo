import { afterAll, describe, expect, test } from "bun:test";
import {
  chmodSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readlinkSync,
  realpathSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";

// `marchyo bg set` / `bg next` under marchyo.theme.followWallpaper, end to end
// against a fake home: a manifest carrying the flag, a build-variant theme
// dir behind the HM profile's declarative pointer, a current-theme pointer
// whose wallpaper sits in a two-image directory, and a stub `matugen` on a
// PATH holding nothing else (so no real awww/notify-send/dconf runs).

const CLI = join(import.meta.dir, "..", "src", "cli.tsx");
const roots: string[] = [];

afterAll(() => {
  for (const r of roots) rmSync(r, { recursive: true, force: true });
});

const write = (path: string, text: string): void => {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, text);
};

const slots = Object.fromEntries(
  Array.from({ length: 16 }, (_, i) => {
    const slot = `base0${i.toString(16).toUpperCase()}`;
    return [slot, `#a0b0${i.toString(16).padStart(2, "0")}`];
  }),
);
const matugenJson = JSON.stringify({
  is_dark_mode: true,
  base16: Object.fromEntries(
    Object.entries(slots).map(([k, v]) => [k, { default: { color: v } }]),
  ),
});
// The token set the generated surfaces resolve (as in theme.test.ts).
const palette = {
  tokens: {
    bg: "#0c0f14",
    text: "#d1d4dc",
    accent: "#f5a351",
    "accent-hover": "#ffb063",
    "accent-subtle": "#281604",
    "border-strong": "#3f4754",
    border: "#242c37",
    surface: "#1c1f24",
    "status-err": "#ff8271",
    "text-heading": "#e7ebf2",
    "text-muted": "#878b91",
    "syn-variable": "#00a3ee",
  },
  tokenSlots: {
    bg: "base00",
    text: "base05",
    accent: "base09",
    "accent-hover": "base09",
    "accent-subtle": "base01",
    "border-strong": "base04",
    border: "base03",
    surface: "base02",
    "status-err": "base08",
    "text-heading": "base06",
    "text-muted": "base04",
  },
};

type Fixture = {
  root: string;
  env: Record<string, string>;
  walls: string[];
  generatedDir: string;
};

function fixture(opts: {
  follow: boolean | undefined;
  matugenFails?: boolean;
}): Fixture {
  const root = mkdtempSync(join(tmpdir(), "marchyo-bg-follow-"));
  roots.push(root);
  const dirs = {
    config: join(root, "config"),
    state: join(root, "state"),
    data: join(root, "data"),
  };

  const buildDir = join(root, "store", "marchyo-theme-dark");
  write(join(buildDir, "palette.json"), JSON.stringify(palette));
  write(
    join(buildDir, "colors.json"),
    JSON.stringify({
      name: "jylhis-dark",
      variant: "dark",
      colors: { bg: "#0c0f14" },
    }),
  );
  const walls = [join(root, "walls", "a.png"), join(root, "walls", "b.png")];
  for (const w of walls) write(w, "png");
  symlinkSync(walls[0]!, join(buildDir, "wallpaper.png"));

  const declarative = join(
    dirs.state,
    "nix/profiles/home-manager/home-files/.config/marchyo/current-theme",
  );
  mkdirSync(dirname(declarative), { recursive: true });
  symlinkSync(buildDir, declarative);
  mkdirSync(join(dirs.config, "marchyo"), { recursive: true });
  symlinkSync(buildDir, join(dirs.config, "marchyo", "current-theme"));

  const themes = [{ name: "jylhis-dark", variant: "dark", dir: buildDir }];
  write(
    join(dirs.data, "marchyo", "themes", "manifest.json"),
    JSON.stringify(
      opts.follow === undefined
        ? themes
        : { themes, followWallpaper: opts.follow },
    ),
  );

  const bin = join(root, "bin");
  // printf is a shell builtin: the stub PATH has no coreutils.
  write(
    join(bin, "matugen"),
    opts.matugenFails
      ? "#!/bin/sh\nexit 1\n"
      : `#!/bin/sh\nprintf '%s\\n' '${matugenJson}'\n`,
  );
  chmodSync(join(bin, "matugen"), 0o755);

  return {
    root,
    walls,
    generatedDir: join(dirs.state, "marchyo", "generated-theme"),
    env: {
      PATH: `${bin}:${dirname(process.execPath)}`,
      XDG_CONFIG_HOME: dirs.config,
      XDG_STATE_HOME: dirs.state,
      XDG_DATA_HOME: dirs.data,
    },
  };
}

async function run(
  args: string[],
  env: Record<string, string>,
): Promise<{ code: number; stdout: string; stderr: string }> {
  const base: Record<string, string> = {};
  for (const [k, v] of Object.entries(process.env)) {
    if (v !== undefined && k !== "HYPRLAND_INSTANCE_SIGNATURE") base[k] = v;
  }
  const proc = Bun.spawn([process.execPath, CLI, ...args], {
    stdout: "pipe",
    stderr: "pipe",
    env: { ...base, NO_COLOR: "1", ...env },
  });
  const code = await proc.exited;
  const stdout = await new Response(proc.stdout).text();
  const stderr = await new Response(proc.stderr).text();
  return { code, stdout, stderr };
}

async function overrides(
  env: Record<string, string>,
): Promise<Record<string, unknown>> {
  const r = await run(["runtime", "status", "--json"], env);
  expect(r.code).toBe(0);
  const list = JSON.parse(r.stdout).overrides as {
    key: string;
    value: unknown;
  }[];
  return Object.fromEntries(list.map((o) => [o.key, o.value]));
}

describe("bg with followWallpaper", () => {
  test("bg set generates a theme from the new image", async () => {
    const f = fixture({ follow: true });
    const r = await run(["bg", "set", f.walls[1]!], f.env);
    expect(r.code).toBe(0);

    const o = await overrides(f.env);
    expect(o["bg.image"]).toBe(f.walls[1]);
    expect(JSON.parse(o["theme.generate"] as string)).toEqual({
      image: f.walls[1],
      variant: "auto",
    });
    expect(
      realpathSync(join(f.env.XDG_CONFIG_HOME!, "marchyo", "current-theme")),
    ).toBe(realpathSync(f.generatedDir));
    expect(readlinkSync(join(f.generatedDir, "wallpaper.png"))).toBe(
      f.walls[1]!,
    );
  });

  test("bg next generates a theme from the next image", async () => {
    const f = fixture({ follow: true });
    const r = await run(["bg", "next"], f.env);
    expect(r.code).toBe(0);

    const o = await overrides(f.env);
    expect(o["bg.image"]).toBe(realpathSync(f.walls[1]!));
    expect(JSON.parse(o["theme.generate"] as string).image).toBe(
      realpathSync(f.walls[1]!),
    );
  });

  test("a failed generation keeps the wallpaper and still exits 0", async () => {
    const f = fixture({ follow: true, matugenFails: true });
    const r = await run(["bg", "set", f.walls[1]!], f.env);
    expect(r.code).toBe(0);
    expect(r.stderr).toContain("generating a theme from it failed");

    const o = await overrides(f.env);
    expect(o["bg.image"]).toBe(f.walls[1]);
    expect(o["theme.generate"]).toBeUndefined();
  });
});

describe("bg without followWallpaper", () => {
  for (const follow of [false, undefined]) {
    const label = follow === undefined ? "array manifest" : "flag off";
    test(`bg set and bg next leave the theme alone (${label})`, async () => {
      const f = fixture({ follow });
      let r = await run(["bg", "set", f.walls[1]!], f.env);
      expect(r.code).toBe(0);
      r = await run(["bg", "next"], f.env);
      expect(r.code).toBe(0);

      const o = await overrides(f.env);
      expect(o["bg.image"]).toBeDefined();
      expect(o["theme.generate"]).toBeUndefined();
      expect(existsSync(f.generatedDir)).toBe(false);
    });
  }
});

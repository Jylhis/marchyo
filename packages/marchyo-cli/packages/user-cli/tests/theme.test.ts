import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import {
  chmodSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  readlinkSync,
  realpathSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { hyprctlEvalArgv, hyprctlKeywordArgv } from "@marchyo/core";
import {
  hyprlandConfigLua,
  hyprlandConfigTable,
} from "../src/commands/theme.ts";

describe("hyprctlEvalArgv", () => {
  test("builds the eval argv with the code as one argument", () => {
    const code = 'hl.config({ ["general"] = { ["col.active_border"] = "rgba(e0a33aff)" } })';
    expect(hyprctlEvalArgv(code)).toEqual(["hyprctl", "eval", code]);
  });

  test("the keyword builder still exists for hyprlang holdouts", () => {
    expect(hyprctlKeywordArgv("general:gaps_in", "5")).toEqual([
      "hyprctl",
      "keyword",
      "general:gaps_in",
      "5",
    ]);
  });
});

describe("hyprlandConfigTable", () => {
  test("groups section:subkey lines, split on the first colon and space", () => {
    // The exact shape theme-runtime.nix's hyprlandKeywordsFor emits.
    const conf = [
      "misc:background_color rgb(0d0f14)",
      "general:col.active_border rgba(e0a33aff)",
      "general:col.inactive_border rgba(3a4150ff)",
      "",
    ].join("\n");
    expect(hyprlandConfigTable(conf)).toEqual({
      misc: { background_color: "rgb(0d0f14)" },
      general: {
        "col.active_border": "rgba(e0a33aff)",
        "col.inactive_border": "rgba(3a4150ff)",
      },
    });
  });

  test("later lines override earlier ones for the same key", () => {
    const conf = "general:gaps_in 5\ngeneral:gaps_in 0";
    expect(hyprlandConfigTable(conf)).toEqual({ general: { gaps_in: "0" } });
  });

  test("skips malformed lines: no space, no colon, or leading colon", () => {
    const conf = ["", "nocolon value", ":leadingcolon value", "novalue"].join(
      "\n",
    );
    expect(hyprlandConfigTable(conf)).toEqual({});
  });

  test("empty and whitespace-only input yield {}", () => {
    expect(hyprlandConfigTable("")).toEqual({});
    expect(hyprlandConfigTable("\n\n")).toEqual({});
  });
});

describe("hyprlandConfigLua", () => {
  test("renders the verified hl.config table literal", () => {
    // Byte-for-byte the form validated live against Hyprland's Lua runtime.
    expect(
      hyprlandConfigLua({
        general: {
          "col.active_border": "rgba(e0a33aff)",
          "col.inactive_border": "rgba(3a4150ff)",
        },
        misc: { background_color: "rgb(0d0f14)" },
      }),
    ).toBe(
      'hl.config({ ["general"] = { ["col.active_border"] = "rgba(e0a33aff)", ' +
        '["col.inactive_border"] = "rgba(3a4150ff)" }, ' +
        '["misc"] = { ["background_color"] = "rgb(0d0f14)" } })',
    );
  });

  test("empty table renders an empty config call", () => {
    expect(hyprlandConfigLua({})).toBe("hl.config({  })");
  });
});

// `theme generate` end to end against a fake home: a build-variant theme dir
// (palette.json, colors.json, templates/, bat.conf) behind the HM profile's
// declarative pointer, and stub `matugen` / `bat` on PATH. Every file a Nix
// scheme theme dir carries must come out of the generated dir, with no
// placeholder left and no build hex where a slot applies.
describe("generateThemeChangeBase.runtimeApply", () => {
  const root = mkdtempSync(join(tmpdir(), "marchyo-generate-"));
  const themeModule = join(import.meta.dir, "..", "src", "commands", "theme.ts");
  const runtimeModule = join(import.meta.dir, "../../core/src/runtime.ts");
  const dirs = {
    config: join(root, "config"),
    state: join(root, "state"),
    data: join(root, "data"),
  };
  const buildDir = join(root, "store", "marchyo-theme-dark");
  const batDir = join(root, "batcfg");
  const image = join(root, "wall.png");

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

  const write = (path: string, text: string): void => {
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, text);
  };

  beforeAll(() => {
    write(join(buildDir, "palette.json"), JSON.stringify(palette));
    write(
      join(buildDir, "colors.json"),
      JSON.stringify({
        name: "jylhis-dark",
        variant: "dark",
        colors: { bg: "#0c0f14", accentHover: "#ffb063", synVariable: "#00a3ee" },
      }),
    );
    write(join(buildDir, "templates", "mako.conf"), "background-color={{token:bg}}\n");
    write(
      join(buildDir, "templates", "waybar.css"),
      "#cpu { color: {{token:accent}}; border-color: {{token:syn-variable}}; }\n",
    );
    write(
      join(buildDir, "templates", "gtk.css"),
      "@define-color shade_color {{shade}};\n@define-color fg {{token:text}};\n",
    );
    write(join(buildDir, "bat.conf"), "--theme=jylhis-dark\n--style=plain\n");
    write(image, "png");

    const pointer = join(
      dirs.state,
      "nix/profiles/home-manager/home-files/.config/marchyo/current-theme",
    );
    mkdirSync(dirname(pointer), { recursive: true });
    symlinkSync(buildDir, pointer);

    const bin = join(root, "bin");
    write(join(bin, "matugen.json"), matugenJson);
    write(join(bin, "matugen"), `#!/bin/sh\ncat ${join(bin, "matugen.json")}\n`);
    write(join(bin, "bat"), `#!/bin/sh\necho ${batDir}\n`);
    chmodSync(join(bin, "matugen"), 0o755);
    chmodSync(join(bin, "bat"), 0o755);

  });

  afterAll(() => {
    rmSync(root, { recursive: true, force: true });
  });

  // Bun.spawn resolves binaries against the environment the process started
  // with, so the stub PATH and XDG dirs need a child process: a driver that
  // calls runtimeApply with a recording exec seam and prints the result.
  function runGenerate(value: string): { applied: unknown; execs: string[][] } {
    const driver = join(root, "driver.ts");
    writeFileSync(
      driver,
      `import { buildRuntime } from ${JSON.stringify(runtimeModule)};
import { generateThemeChangeBase } from ${JSON.stringify(themeModule)};
const execs: string[][] = [];
const applied = await generateThemeChangeBase.runtimeApply({
  rt: buildRuntime({ quiet: true }, {}, false),
  exec: async (argv) => { execs.push(argv); return 0; },
  value: ${JSON.stringify(value)},
});
console.log(JSON.stringify({ applied, execs }));
`,
    );
    const env: Record<string, string> = {};
    for (const [k, v] of Object.entries(process.env)) {
      if (v !== undefined && k !== "HYPRLAND_INSTANCE_SIGNATURE") env[k] = v;
    }
    const proc = Bun.spawnSync([process.execPath, driver], {
      cwd: dirname(themeModule),
      env: {
        ...env,
        PATH: `${join(root, "bin")}:${process.env.PATH ?? ""}`,
        XDG_CONFIG_HOME: dirs.config,
        XDG_STATE_HOME: dirs.state,
        XDG_DATA_HOME: dirs.data,
      },
      stdout: "pipe",
      stderr: "pipe",
    });
    if (proc.exitCode !== 0) throw new Error(proc.stderr.toString());
    return JSON.parse(proc.stdout.toString());
  }

  test("writes the full theme-dir file set and activates it", async () => {
    const value = JSON.stringify({ image, variant: "auto" });
    const { applied, execs } = runGenerate(value);
    expect(applied).toBe(value);

    const dir = join(dirs.state, "marchyo", "generated-theme");
    expect(readdirSync(dir).sort()).toEqual(
      [
        "bat.conf",
        "colors.json",
        "console.txt",
        "fzf.opts",
        "gdu.yaml",
        "ghostty.conf",
        "gtk.css",
        "hyprland.conf",
        "hyprlock-colors.conf",
        "k9s-skin.yaml",
        "lazygit.yml",
        "mako.conf",
        "palette.json",
        "spotify-player-theme.toml",
        "variant",
        "wallpaper.png",
        "waybar.css",
      ].sort(),
    );
    const read = (f: string): string => readFileSync(join(dir, f), "utf8");

    expect(read("variant")).toBe("dark\n");
    expect(read("mako.conf")).toBe(`background-color=${slots.base00}\n`);
    // syn-variable has no slot: it keeps the build hex.
    expect(read("waybar.css")).toBe(
      `#cpu { color: ${slots.base09}; border-color: #00a3ee; }\n`,
    );
    expect(read("gtk.css")).toBe(
      "@define-color shade_color rgba(160, 176, 5, 0.08);\n" +
        `@define-color fg ${slots.base05};\n`,
    );
    for (const f of ["mako.conf", "waybar.css", "gtk.css"]) {
      expect(read(f)).not.toContain("{{");
    }
    expect(read("hyprlock-colors.conf")).toContain("$bg = rgba(a0b000ff)");
    expect(read("console.txt").trim().split("\n")).toHaveLength(3);
    expect(read("bat.conf")).toBe("--theme=marchyo-generated\n--style=plain\n");
    expect(read("k9s-skin.yaml")).toContain(`fgColor: "${slots.base05}"`);
    expect(read("lazygit.yml")).toContain(
      `defaultFgColor: ["${slots.base05}"]`,
    );
    expect(read("spotify-player-theme.toml")).toContain(
      `background = "${slots.base00}"`,
    );
    expect(read("gdu.yaml")).toContain(`text-color: "${slots.base05}"`);
    expect(JSON.parse(read("colors.json")).colors).toEqual({
      bg: slots.base00,
      accentHover: slots.base09,
      synVariable: "#00a3ee",
    });
    expect(JSON.parse(read("palette.json")).tokens.accent).toBe(slots.base09);
    expect(readlinkSync(join(dir, "wallpaper.png"))).toBe(image);

    // bat: tmTheme registered and the cache rebuilt before activation.
    expect(
      readFileSync(join(batDir, "themes", "marchyo-generated.tmTheme"), "utf8"),
    ).toContain(`<string>${slots.base00}</string>`);
    expect(execs).toContainEqual(["bat", "cache", "--build"]);

    // activateThemeDir: pointer and relinked surfaces target the generated dir.
    expect(realpathSync(join(dirs.config, "marchyo", "current-theme"))).toBe(
      realpathSync(dir),
    );
    for (const link of [
      "mako/config",
      "waybar/style.css",
      "gtk-3.0/gtk.css",
      "gtk-4.0/gtk.css",
      "bat/config",
      "k9s/skins/jylhis.yaml",
    ]) {
      expect(existsSync(join(dirs.config, link))).toBe(true);
      expect(readlinkSync(join(dirs.config, link)).startsWith(dir)).toBe(true);
    }
    expect(execs).toContainEqual(["setvtrgb", join(dir, "console.txt")]);
  });
});

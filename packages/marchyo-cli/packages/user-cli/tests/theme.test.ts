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
import parity from "../../core/tests/fixtures/theme-parity.json";
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
    tokens: parity.palette.tokens,
    tokenSlots: parity.palette.tokenSlots,
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
    write(
      join(buildDir, "templates", "gtk.css"),
      "@define-color shade_color {{shade}};\n@define-color fg {{token:text}};\n",
    );
    write(join(buildDir, "bat.conf"), "--theme=jylhis-dark\n--style=plain\n");
    for (const f of [
      "btop.theme",
      "kitty.conf",
      "foot-theme.ini",
      "alacritty-theme.toml",
      "helix-theme.toml",
      "nvim-theme.lua",
      "emacs-theme.el",
    ]) {
      write(join(buildDir, "templates", f), `bg={{token:bg}} fg={{token:text}}\n`);
    }
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
  function runGenerate(
    value: string,
    restore = false,
    failPreference = false,
  ): { applied: unknown; execs: string[][] } {
    const driver = join(root, "driver.ts");
    writeFileSync(
      driver,
      `import { buildRuntime } from ${JSON.stringify(runtimeModule)};
import { generateThemeChangeBase, restoreEffectiveTheme } from ${JSON.stringify(themeModule)};
const execs: string[][] = [];
const ctx = {
  rt: buildRuntime({ quiet: true }, {}, false),
  exec: async (argv: string[]) => {
    execs.push(argv);
    return ${failPreference} && argv[0] === "dconf" ? 1 : 0;
  },
  value: ${JSON.stringify(value)},
};
const applied = ${restore
  ? "await restoreEffectiveTheme(ctx, { \"theme.generate\": ctx.value })"
  : "await generateThemeChangeBase.runtimeApply(ctx)"};
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
        "alacritty-theme.toml",
        "bat.conf",
        "btop.theme",
        "colors.json",
        "console.txt",
        "emacs-theme.el",
        "fcitx5-theme.conf",
        "foot-theme.ini",
        "fzf.opts",
        "gdu.yaml",
        "ghostty.conf",
        "gtk.css",
        "helix-theme.toml",
        "hyprland.conf",
        "hyprlock-colors.conf",
        "k9s-skin.yaml",
        "kitty.conf",
        "lazygit.yml",
        "nvim-theme.lua",
        "palette.json",
        "spotify-player-theme.toml",
        "tmux.conf",
        "variant",
        "wallpaper.png",
      ].sort(),
    );
    const read = (f: string): string => readFileSync(join(dir, f), "utf8");

    expect(read("variant")).toBe("dark\n");
    expect(read("gtk.css")).toBe(
      "@define-color shade_color rgba(160, 176, 5, 0.08);\n" +
        `@define-color fg ${slots.base05};\n`,
    );
    for (const f of [
      "gtk.css",
      "btop.theme",
      "kitty.conf",
      "foot-theme.ini",
      "alacritty-theme.toml",
      "helix-theme.toml",
      "nvim-theme.lua",
      "emacs-theme.el",
    ]) {
      expect(read(f)).not.toContain("{{");
    }
    expect(read("kitty.conf")).toBe(`bg=${slots.base00} fg=${slots.base05}\n`);
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
      accentHover: slots.base06,
      synVariable: slots.base08,
    });
    expect(JSON.parse(read("palette.json")).tokens.accent).toBe(slots.base05);
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
      "gtk-3.0/gtk.css",
      "gtk-4.0/gtk.css",
      "bat/config",
      "k9s/skins/jylhis.yaml",
    ]) {
      expect(existsSync(join(dirs.config, link))).toBe(true);
      expect(readlinkSync(join(dirs.config, link)).startsWith(dir)).toBe(true);
    }
    expect(execs).toContainEqual(["setvtrgb", join(dir, "console.txt")]);

    // Terminal and editor surfaces: relinked at the generated dir, reloaded.
    for (const [file, link] of [
      ["btop.theme", join(dirs.config, "btop/themes/marchyo.theme")],
      ["kitty.conf", join(dirs.config, "kitty/marchyo-theme.conf")],
      ["foot-theme.ini", join(dirs.config, "foot/marchyo-theme.ini")],
      ["alacritty-theme.toml", join(dirs.config, "alacritty/marchyo-theme.toml")],
      ["helix-theme.toml", join(dirs.config, "helix/themes/marchyo.toml")],
      ["nvim-theme.lua", join(dirs.data, "nvim/site/colors/marchyo.lua")],
    ] as const) {
      expect(readlinkSync(link)).toBe(join(dir, file));
    }
    expect(execs).toContainEqual(["pkill", "-USR2", "-x", "btop"]);
    expect(execs).toContainEqual([
      "kitty", "@", "set-colors", "-a", "-c", join(dir, "kitty.conf"),
    ]);
    expect(execs.some((a) => a[0] === "emacsclient")).toBe(true);
  });

  test("restores generated selections and preserves active assets on preference failure", () => {
    const value = JSON.stringify({ image, variant: "dark" });
    const { applied, execs } = runGenerate(value, true);
    expect(applied).toBe(true);
    expect(execs).toContainEqual([
      "dconf", "write", "/org/gnome/desktop/interface/color-scheme", "'prefer-dark'",
    ]);
    const colors = join(dirs.state, "marchyo", "generated-theme", "colors.json");
    const before = readFileSync(colors, "utf8");
    expect(() => runGenerate(
      JSON.stringify({ image, variant: "light" }), true, true,
    )).toThrow("Cannot set the desktop preference");
    expect(readFileSync(colors, "utf8")).toBe(before);
  });

  test("Material outline/container roles override the base16 fallback", () => {
    const tokensOf = (): Record<string, string> =>
      JSON.parse(
        readFileSync(
          join(dirs.state, "marchyo", "generated-theme", "palette.json"),
          "utf8",
        ),
      ).tokens;
    const value = JSON.stringify({ image, variant: "dark" });

    runGenerate(value);
    expect(tokensOf().border).toBe(slots.base03);
    expect(tokensOf()["accent-subtle"]).toBe(slots.base02);

    const node = (dark: string) => ({
      dark: { color: dark },
      light: { color: "#ffffff" },
      default: { color: dark },
    });
    write(
      join(root, "bin", "matugen.json"),
      JSON.stringify({
        ...JSON.parse(matugenJson),
        colors: {
          outline_variant: node("#11aa01"),
          outline: node("#11aa02"),
          primary_container: node("#11aa03"),
        },
      }),
    );
    runGenerate(value);
    const tokens = tokensOf();
    expect(tokens.border).toBe("#11aa01");
    expect(tokens["border-strong"]).toBe("#11aa02");
    expect(tokens["accent-subtle"]).toBe("#11aa03");
    expect(tokens.bg).toBe(slots.base00);
    write(join(root, "bin", "matugen.json"), matugenJson);
  });
});

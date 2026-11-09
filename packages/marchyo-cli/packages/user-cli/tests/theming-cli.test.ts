import { afterAll, describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";

const CLI = join(import.meta.dir, "..", "src", "cli.tsx");
const roots: string[] = [];
afterAll(() => {
  for (const r of roots) rmSync(r, { recursive: true, force: true });
});

function write(path: string, text: string, mode?: number): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, text, mode === undefined ? undefined : { mode });
}

function sandbox(): { root: string; env: Record<string, string> } {
  const root = mkdtempSync(join(tmpdir(), "marchyo-theming-cli-"));
  roots.push(root);
  const bin = join(root, "bin");
  // fc-list answers the monospace and the all-families queries; dconf reads
  // a session whose GTK font is "Inter 11".
  write(
    join(bin, "fc-list"),
    `#!/bin/sh
case "$1" in
  :mono) printf 'DejaVu Sans Mono\\nFira Code,Fira Code Retina\\n' ;;
  :family=*) printf 'x\\n' ;;
  *) printf 'DejaVu Sans Mono\\nInter,Inter Display\\nFira Code\\n' ;;
esac
`,
    0o755,
  );
  write(join(bin, "fc-match"), "#!/bin/sh\necho DejaVu Sans Mono\n", 0o755);
  write(join(bin, "dconf"), "#!/bin/sh\n[ \"$1\" = read ] && echo \"'Inter 11'\"\nexit 0\n", 0o755);
  return {
    root,
    env: {
      HOME: join(root, "home"),
      XDG_CONFIG_HOME: join(root, "config"),
      XDG_STATE_HOME: join(root, "state"),
      XDG_DATA_HOME: join(root, "data"),
      XDG_DATA_DIRS: join(root, "share"),
      PATH: `${bin}:${process.env.PATH}`,
    },
  };
}

async function run(args: string[], env: Record<string, string>) {
  const clean: Record<string, string> = {};
  for (const [k, v] of Object.entries(process.env)) {
    if (v !== undefined && k !== "HYPRLAND_INSTANCE_SIGNATURE") clean[k] = v;
  }
  const proc = Bun.spawn([process.execPath, CLI, ...args], {
    stdout: "pipe",
    stderr: "pipe",
    env: { ...clean, NO_COLOR: "1", ...env },
  });
  const code = await proc.exited;
  return {
    code,
    stdout: await new Response(proc.stdout).text(),
    stderr: await new Response(proc.stderr).text(),
  };
}

describe("font list and set", () => {
  test("list defaults to monospace families and carries the current fonts", async () => {
    const { env } = sandbox();
    const r = await run(["font", "list", "--format", "json"], env);
    expect(r.code).toBe(0);
    expect(JSON.parse(r.stdout)).toEqual({
      kind: "mono",
      fonts: ["DejaVu Sans Mono", "Fira Code"],
      current: { mono: "DejaVu Sans Mono", ui: "Inter" },
    });
    const text = await run(["font", "list"], env);
    expect(text.stdout).toBe("DejaVu Sans Mono\nFira Code\n");
  });

  test("--kind ui lists the proportional families, --kind all every family", async () => {
    const { env } = sandbox();
    const ui = JSON.parse((await run(["font", "list", "--kind", "ui", "--json"], env)).stdout);
    expect(ui.fonts).toEqual(["Inter"]);
    const all = JSON.parse((await run(["font", "list", "--kind", "all", "--json"], env)).stdout);
    expect(all.fonts).toEqual(["DejaVu Sans Mono", "Fira Code", "Inter"]);
    expect((await run(["font", "list", "--kind", "serif"], env)).code).toBe(2);
  });

  test("font set --kind ui records font.ui and writes the shell style file", async () => {
    const { root, env } = sandbox();
    const r = await run(["font", "set", "Inter", "--kind", "ui"], env);
    expect(r.code).toBe(0);
    const overrides = JSON.parse((await run(["runtime", "status", "--json"], env)).stdout);
    expect(overrides.overrides).toEqual([{ key: "font.ui", value: "Inter" }]);
    const style = await Bun.file(join(root, "state", "marchyo", "shell", "style.json")).json();
    expect(style).toEqual({ uiFont: "Inter" });

    const back = await run(["font", "set", "--kind", "ui", "--revert"], env);
    expect(back.code).toBe(0);
    expect(
      JSON.parse((await run(["runtime", "status", "--json"], env)).stdout).overrides,
    ).toEqual([]);
  });
});

describe("theme list, gaps and icons", () => {
  test("theme list reports preview and wallpaper paths when the theme dir has them", async () => {
    const { root, env } = sandbox();
    const withImages = join(root, "themes", "alpha");
    const bare = join(root, "themes", "beta");
    write(join(withImages, "preview.png"), "p");
    write(join(withImages, "wallpaper.png"), "w");
    write(join(bare, "variant"), "dark\n");
    write(
      join(root, "data", "marchyo", "themes", "manifest.json"),
      JSON.stringify([
        { name: "alpha", variant: "dark", dir: withImages },
        { name: "beta", variant: "light", dir: bare },
      ]),
    );
    const r = await run(["theme", "list", "--json"], env);
    const themes = JSON.parse(r.stdout).themes;
    expect(themes[0]).toMatchObject({
      name: "alpha",
      preview: join(withImages, "preview.png"),
      wallpaper: join(withImages, "wallpaper.png"),
    });
    expect(themes[1]).not.toHaveProperty("preview");
    expect(themes[1]).not.toHaveProperty("wallpaper");
  });

  test("theme gaps lists the modes, rejects bad values and --apply needs a value", async () => {
    const { env } = sandbox();
    const list = await run(["theme", "gaps", "--json"], env);
    expect(JSON.parse(list.stdout).gaps).toEqual({ declarative: false, modes: ["on", "off"] });
    expect((await run(["theme", "gaps", "sometimes"], env)).code).toBe(2);
    expect((await run(["theme", "gaps", "on", "--apply", "--revert"], env)).code).toBe(2);
  });

  test("theme gaps on records appearance.gaps for runtime restore", async () => {
    const { env } = sandbox();
    expect((await run(["theme", "gaps", "on"], env)).code).toBe(0);
    const status = JSON.parse((await run(["runtime", "status", "--json"], env)).stdout);
    expect(status.overrides).toEqual([{ key: "appearance.gaps", value: true }]);
    expect((await run(["runtime", "restore"], env)).code).toBe(0);
  });

  test("bar position and background list modes and write the style file", async () => {
    const { root, env } = sandbox();
    const modes = JSON.parse((await run(["theme", "bar-position", "--json"], env)).stdout);
    expect(modes["bar-position"].modes).toEqual(["top", "bottom"]);
    expect((await run(["theme", "bar-position", "bottom"], env)).code).toBe(0);
    expect((await run(["theme", "bar-background", "glassy"], env)).code).toBe(0);
    expect((await run(["theme", "bar-background", "frosted"], env)).code).toBe(2);
    expect(
      await Bun.file(join(root, "state", "marchyo", "shell", "style.json")).json(),
    ).toEqual({ barPosition: "bottom", barBackground: "glassy" });
  });

  test("theme icons lists installed themes and rejects an unknown one", async () => {
    const { root, env } = sandbox();
    write(
      join(root, "share", "icons", "Papirus", "index.theme"),
      "[Icon Theme]\nDirectories=48x48/apps\n",
    );
    const list = JSON.parse((await run(["theme", "icons", "--json"], env)).stdout);
    expect(list.icons.themes).toEqual(["Papirus"]);
    expect((await run(["theme", "icons", "Nope"], env)).code).toBe(2);
    expect((await run(["theme", "icons", "Papirus"], env)).code).toBe(0);
    const status = JSON.parse((await run(["runtime", "status", "--json"], env)).stdout);
    expect(status.overrides).toEqual([{ key: "appearance.iconTheme", value: "Papirus" }]);
  });
});

describe("bg list and next", () => {
  function wallpaperFixture() {
    const sb = sandbox();
    const pkg = join(sb.root, "store", "wallpapers");
    const theme = join(sb.root, "store", "theme");
    write(join(pkg, "a.png"), "a");
    write(join(pkg, "c.png"), "c");
    write(join(theme, "wallpapers", "b.png"), "b");
    mkdirSync(theme, { recursive: true });
    symlinkSync(join(pkg, "a.png"), join(theme, "wallpaper.png"));
    mkdirSync(join(sb.root, "config", "marchyo"), { recursive: true });
    symlinkSync(theme, join(sb.root, "config", "marchyo", "current-theme"));
    write(join(sb.root, "home", "Pictures", "Wallpapers", "d.jpg"), "d");
    return { ...sb, pkg, theme };
  }

  test("lists theme, package and user wallpapers once each and marks the current one", async () => {
    const { root, pkg, theme, env } = wallpaperFixture();
    const r = await run(["bg", "list", "--format", "json"], env);
    expect(r.code).toBe(0);
    expect(JSON.parse(r.stdout)).toEqual([
      { path: join(theme, "wallpaper.png"), name: "a", source: "theme", current: true },
      { path: join(theme, "wallpapers", "b.png"), name: "b", source: "theme", current: false },
      { path: join(pkg, "c.png"), name: "c", source: "package", current: false },
      {
        path: join(root, "home", "Pictures", "Wallpapers", "d.jpg"),
        name: "d",
        source: "user",
        current: false,
      },
    ]);
  });

  test("bg next cycles the same list and the runtime override moves the current mark", async () => {
    const { theme, env } = wallpaperFixture();
    expect((await run(["bg", "next"], env)).code).toBe(0);
    const overrides = JSON.parse((await run(["runtime", "status", "--json"], env)).stdout);
    expect(overrides.overrides).toEqual([
      { key: "bg.image", value: join(theme, "wallpapers", "b.png") },
    ]);
    const list = JSON.parse((await run(["bg", "list", "--json"], env)).stdout);
    expect(list.map((w: { current: boolean }) => w.current)).toEqual([false, true, false, false]);
  });

  test("bg list offers only package wallpapers of the theme's polarity", async () => {
    const sb = sandbox();
    const pkg = join(sb.root, "store", "wallpapers");
    const theme = join(sb.root, "store", "theme");
    for (const f of ["grid-dark.png", "dots-dark.png", "grid-light.png", "dots-light.png"]) {
      write(join(pkg, f), f);
    }
    write(join(theme, "variant"), "dark\n");
    symlinkSync(join(pkg, "grid-dark.png"), join(theme, "wallpaper.png"));
    mkdirSync(join(sb.root, "config", "marchyo"), { recursive: true });
    symlinkSync(theme, join(sb.root, "config", "marchyo", "current-theme"));
    const list = JSON.parse((await run(["bg", "list", "--json"], sb.env)).stdout);
    expect(list.map((w: { name: string }) => w.name)).toEqual(["grid-dark", "dots-dark"]);
  });

  test("bg list is empty without a theme or wallpaper directory", async () => {
    const { env } = sandbox();
    const r = await run(["bg", "list", "--json"], env);
    expect(JSON.parse(r.stdout)).toEqual([]);
    expect((await run(["bg", "next"], env)).code).toBe(1);
  });
});

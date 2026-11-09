import { describe, expect, test } from "bun:test";
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readlinkSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  activateAppSurfaces,
  relinkSurface,
} from "../src/commands/theme-surfaces.ts";

const tmp = (): string => mkdtempSync(join(tmpdir(), "marchyo-surfaces-"));

describe("activateAppSurfaces", () => {
  test("reloads tmux when its config sources the pointer", async () => {
    const root = tmp();
    const dir = join(root, "theme");
    const config = join(root, "config");
    mkdirSync(dir);
    mkdirSync(join(config, "tmux"), { recursive: true });
    writeFileSync(join(dir, "tmux.conf"), "set -g x y\n");
    writeFileSync(
      join(config, "tmux", "tmux.conf"),
      "source-file -q /h/.config/marchyo/current-theme/tmux.conf\n",
    );
    const calls: string[][] = [];
    await activateAppSurfaces(async (a) => void calls.push(a), config, dir);
    expect(calls).toContainEqual(["tmux", "source-file", join(dir, "tmux.conf")]);
  });
});

describe("relinkSurface", () => {
  test("creates an absent link, replaces a stale one, keeps a user file", async () => {
    const root = tmp();
    const target = join(root, "new", "btop.theme");
    const other = join(root, "old", "btop.theme");
    mkdirSync(join(root, "new"));
    mkdirSync(join(root, "old"));
    writeFileSync(target, "n");
    writeFileSync(other, "o");

    const link = join(root, "cfg", "btop", "themes", "marchyo.theme");
    await relinkSurface(other, link);
    expect(readlinkSync(link)).toBe(other);
    await relinkSurface(target, link);
    expect(readlinkSync(link)).toBe(target);

    const own = join(root, "cfg", "own.theme");
    writeFileSync(own, "mine");
    await relinkSurface(target, own);
    expect(readFileSync(own, "utf8")).toBe("mine");
  });

  test("a link that already resolves to the target is left alone", async () => {
    const root = tmp();
    const target = join(root, "theme", "kitty.conf");
    mkdirSync(join(root, "theme"));
    writeFileSync(target, "k");
    const pointer = join(root, "current-theme");
    symlinkSync(join(root, "theme"), pointer);
    const link = join(root, "cfg", "marchyo-theme.conf");
    mkdirSync(join(root, "cfg"));
    symlinkSync(join(pointer, "kitty.conf"), link);
    await relinkSurface(target, link);
    expect(readlinkSync(link)).toBe(join(pointer, "kitty.conf"));
  });
});

describe("terminal and editor surfaces", () => {
  test("relinks each surface, signals btop, recolours kitty and reloads Emacs", async () => {
    const root = tmp();
    const dir = join(root, "theme");
    const config = join(root, "config");
    const data = join(root, "data");
    mkdirSync(dir);
    const files = [
      "btop.theme", "kitty.conf", "foot-theme.ini", "alacritty-theme.toml",
      "helix-theme.toml", "nvim-theme.lua", "emacs-theme.el",
    ];
    for (const f of files) writeFileSync(join(dir, f), `${f}\n`);
    process.env.XDG_DATA_HOME = data;
    const calls: string[][] = [];
    await activateAppSurfaces(async (a) => void calls.push(a), config, dir);
    delete process.env.XDG_DATA_HOME;

    const links: Record<string, string> = {
      "btop.theme": join(config, "btop", "themes", "marchyo.theme"),
      "kitty.conf": join(config, "kitty", "marchyo-theme.conf"),
      "foot-theme.ini": join(config, "foot", "marchyo-theme.ini"),
      "alacritty-theme.toml": join(config, "alacritty", "marchyo-theme.toml"),
      "helix-theme.toml": join(config, "helix", "themes", "marchyo.toml"),
      "nvim-theme.lua": join(data, "nvim", "site", "colors", "marchyo.lua"),
    };
    for (const [file, link] of Object.entries(links)) {
      expect(readlinkSync(link)).toBe(join(dir, file));
    }
    expect(calls).toContainEqual(["pkill", "-USR2", "-x", "btop"]);
    expect(calls).toContainEqual(["kitty", "@", "set-colors", "-a", "-c", join(dir, "kitty.conf")]);
    const emacs = calls.find((c) => c[0] === "emacsclient")!;
    expect(emacs.at(-1)).toBe(`(load-file ${JSON.stringify(join(dir, "emacs-theme.el"))})`);
  });

  test("a theme dir without these files runs no extra command", async () => {
    const root = tmp();
    const dir = join(root, "theme");
    mkdirSync(dir);
    const calls: string[][] = [];
    await activateAppSurfaces(async (a) => void calls.push(a), join(root, "config"), dir);
    expect(calls.map((c) => c[0])).toEqual(["busctl"]);
  });

  test("one failing command never blocks the other surfaces", async () => {
    const root = tmp();
    const dir = join(root, "theme");
    mkdirSync(dir);
    writeFileSync(join(dir, "btop.theme"), "b");
    writeFileSync(join(dir, "kitty.conf"), "k");
    const calls: string[][] = [];
    await activateAppSurfaces(
      async (a) => {
        calls.push(a);
        throw new Error("boom");
      },
      join(root, "config"),
      dir,
    );
    expect(calls.some((c) => c[0] === "kitty")).toBe(true);
  });
});

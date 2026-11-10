import { afterAll, describe, expect, test } from "bun:test";
import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const CLI = join(import.meta.dir, "..", "src", "cli.tsx");
const roots: string[] = [];
afterAll(() => {
  for (const r of roots) rmSync(r, { recursive: true, force: true });
});

function sandbox() {
  const root = mkdtempSync(join(tmpdir(), "marchyo-bar-cli-"));
  roots.push(root);
  return {
    root,
    layout: join(root, "state", "marchyo", "shell", "bar-layout.json"),
    env: {
      HOME: join(root, "home"),
      XDG_CONFIG_HOME: join(root, "config"),
      XDG_STATE_HOME: join(root, "state"),
      XDG_DATA_HOME: join(root, "data"),
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

const ops = (path: string) => JSON.parse(readFileSync(path, "utf8")).ops;

describe("marchyo bar", () => {
  test("put, move, remove and set record ops the shell applies", async () => {
    const { layout, env } = sandbox();
    expect((await run(["bar", "put", "marchyo.cpu", "centerBegin", "--at", "0"], env)).code).toBe(0);
    expect((await run(["bar", "move", "marchyo.cpu", "left"], env)).code).toBe(0);
    expect((await run(["bar", "remove", "marchyo.media"], env)).code).toBe(0);
    expect((await run(["bar", "set", "centerEnd", "marchyo.dnd", "marchyo.caffeine"], env)).code).toBe(0);
    expect(ops(layout)).toEqual([
      { op: "put", id: "marchyo.cpu", section: "centerBegin", at: 0 },
      { op: "shift", id: "marchyo.cpu", by: -1 },
      { op: "remove", id: "marchyo.media" },
      { op: "set", section: "centerEnd", ids: ["marchyo.dnd", "marchyo.caffeine"] },
    ]);
  });

  test("a second put of the same widget replaces the first", async () => {
    const { layout, env } = sandbox();
    await run(["bar", "put", "marchyo.cpu", "left"], env);
    await run(["bar", "put", "marchyo.cpu", "right"], env);
    expect(ops(layout)).toEqual([{ op: "put", id: "marchyo.cpu", section: "right" }]);
  });

  test("list prints the edits, reset deletes the file and the override", async () => {
    const { layout, env } = sandbox();
    await run(["bar", "put", "marchyo.cpu", "left"], env);
    const list = JSON.parse((await run(["bar", "list", "--format", "json"], env)).stdout);
    expect(list.ops).toEqual([{ op: "put", id: "marchyo.cpu", section: "left" }]);
    const status = JSON.parse((await run(["runtime", "status", "--json"], env)).stdout);
    expect(status.overrides.map((o: { key: string }) => o.key)).toEqual(["appearance.barLayout"]);
    expect((await run(["bar", "reset"], env)).code).toBe(0);
    expect(existsSync(layout)).toBe(false);
    const after = JSON.parse((await run(["runtime", "status", "--json"], env)).stdout);
    expect(after.overrides).toEqual([]);
  });

  test("runtime restore rewrites a deleted layout file from the override", async () => {
    const { layout, env } = sandbox();
    await run(["bar", "put", "marchyo.cpu", "left"], env);
    rmSync(layout);
    expect((await run(["runtime", "restore"], env)).code).toBe(0);
    expect(ops(layout)).toEqual([{ op: "put", id: "marchyo.cpu", section: "left" }]);
  });

  test("bad ids, sections and numbers are usage errors", async () => {
    const { layout, env } = sandbox();
    expect((await run(["bar", "put", "bad id", "left"], env)).code).toBe(2);
    expect((await run(["bar", "put", "marchyo.cpu", "middle"], env)).code).toBe(2);
    expect((await run(["bar", "put", "marchyo.cpu", "left", "--at", "x"], env)).code).toBe(2);
    expect((await run(["bar", "move", "marchyo.cpu", "up"], env)).code).toBe(2);
    expect((await run(["bar", "move", "marchyo.cpu", "left", "x"], env)).code).toBe(2);
    expect((await run(["bar", "set", "left", "ok", "no way"], env)).code).toBe(2);
    expect(existsSync(layout)).toBe(false);
  });

  test("background and position write the shell style file", async () => {
    const { root, env } = sandbox();
    expect((await run(["bar", "background", "clear"], env)).code).toBe(0);
    expect((await run(["bar", "position", "bottom"], env)).code).toBe(0);
    expect(
      JSON.parse(readFileSync(join(root, "state", "marchyo", "shell", "style.json"), "utf8")),
    ).toEqual({ barBackground: "clear", barPosition: "bottom" });
  });
});

import { afterEach, beforeEach, expect, test } from "bun:test";
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { ShellIpcError, type Runtime } from "@marchyo/core";
import { runMenu, runMenuInput, runMenuSelect } from "../src/commands/menu.ts";
import {
  buildMenuRequest,
  formatChoice,
  gumChooseArgv,
  normalizeRoute,
  parseRows,
  requestMenu,
  rowValue,
  tuiTarget,
} from "../src/commands/menu-shell.ts";

const rt: Runtime = {
  format: "text",
  noColor: true,
  forceColor: false,
  plain: false,
  noAnimation: true,
  noInput: true,
  quiet: true,
  verbose: 0,
};

let runtime: string;
beforeEach(() => {
  runtime = mkdtempSync(join(tmpdir(), "menu-shell-"));
});
afterEach(() => rmSync(runtime, { recursive: true, force: true }));

const menuDir = () => join(runtime, "marchyo", "menu");
const noSleep = async () => {};

async function capture(fn: () => Promise<number>): Promise<{ code: number; out: string }> {
  const chunks: string[] = [];
  const orig = process.stdout.write;
  process.stdout.write = ((c: string | Uint8Array) => {
    chunks.push(String(c));
    return true;
  }) as typeof process.stdout.write;
  try {
    const code = await fn();
    return { code, out: chunks.join("") };
  } finally {
    process.stdout.write = orig;
  }
}

test("normalizeRoute lower-cases and joins segments with dots", () => {
  expect(normalizeRoute(undefined)).toBe("");
  expect(normalizeRoute("  ")).toBe("");
  expect(normalizeRoute("Appearance.Theme")).toBe("appearance.theme");
  expect(normalizeRoute("appearance/theme")).toBe("appearance.theme");
  expect(normalizeRoute(".capture.")).toBe("capture");
  expect(normalizeRoute("a..b;rm")).toBe("a.brm");
});

test("tuiTarget maps power and system to the power menu", () => {
  expect(tuiTarget("power")).toBe("power");
  expect(tuiTarget("system")).toBe("power");
  expect(tuiTarget("appearance")).toBe("appearance");
  expect(tuiTarget("appearance.theme")).toBe("appearance");
  expect(tuiTarget("capture")).toBe("main");
  expect(tuiTarget("")).toBe("main");
});

test("parseRows reads label, glyph label, label subtext and glyph label subtext", () => {
  const rows = parseRows(
    ["Plain", "\u{f0e7}\tBolt", "Wi-Fi\tconnected", "ab\tc", "G\tLabel\tsub", "", "\t", "x\ty\tz\tw"].join(
      "\n",
    ) + "\n",
  );
  expect(rows).toEqual([
    { label: "Plain" },
    { glyph: "\u{f0e7}", label: "Bolt" },
    { label: "Wi-Fi", subtext: "connected" },
    { glyph: "ab", label: "c" },
    { glyph: "G", label: "Label", subtext: "sub" },
    { glyph: "x", label: "y", subtext: "z\tw" },
  ]);
});

test("a two-field row is a glyph only up to two code points", () => {
  expect(parseRows("abc\tdef")).toEqual([{ label: "abc", subtext: "def" }]);
  expect(parseRows("\u{1f512}\tLock")).toEqual([{ glyph: "\u{1f512}", label: "Lock" }]);
  expect(parseRows("a\r\n")).toEqual([{ label: "a" }]);
});

test("rowValue never returns the glyph", () => {
  expect(rowValue({ glyph: "G", label: "Lock" })).toBe("Lock");
  expect(rowValue({ glyph: "G", label: "Wi-Fi", subtext: "on" })).toBe("Wi-Fi\ton");
});

test("buildMenuRequest omits unset fields", () => {
  expect(buildMenuRequest("select", { rows: [{ label: "A" }] })).toEqual({
    mode: "select",
    rows: [{ label: "A" }],
  });
  expect(
    buildMenuRequest("select", {
      prompt: "P",
      rows: [{ glyph: "g", label: "A", subtext: "s" }],
      multiple: true,
      selected: ["A"],
      width: 300,
      maxHeight: 200,
      onChange: ["echo", "x"],
      changeKey: "ctrl+p",
    }),
  ).toEqual({
    mode: "select",
    prompt: "P",
    rows: [{ glyph: "g", label: "A", subtext: "s" }],
    multiple: true,
    selected: ["A"],
    width: 300,
    maxHeight: 200,
    onChange: ["echo", "x"],
    changeKey: "ctrl+p",
  });
  expect(buildMenuRequest("input", { prompt: "Name", width: 400 })).toEqual({
    mode: "input",
    prompt: "Name",
    width: 400,
  });
});

test("formatChoice prints a JSON array for multiple choices", () => {
  expect(formatChoice("A\tx", false)).toBe("A\tx");
  expect(formatChoice('["A","B"]', true)).toBe('["A","B"]');
  expect(formatChoice("A\nB\tsub\n", true)).toBe('["A","B\\tsub"]');
});

test("gumChooseArgv keeps preselected rows and multi-select", () => {
  expect(gumChooseArgv("P", [{ label: "A" }, { glyph: "g", label: "B" }], true, ["B"])).toEqual([
    "gum", "choose", "--header", "P", "--no-limit", "--selected", "g  B", "A", "g  B",
  ]);
});

test("requestMenu writes the request, waits for done and removes every file", async () => {
  let reqPath = "";
  let sleeps = 0;
  const out = await requestMenu(buildMenuRequest("input", { prompt: "Q" }), {
    runtimeDir: runtime,
    id: "abc",
    sleep: async () => {
      sleeps++;
      if (sleeps === 2) {
        writeFileSync(reqPath.replace(/\.json$/, ".out"), "typed\n");
        writeFileSync(reqPath.replace(/\.json$/, ".done"), "");
      }
    },
    ipc: async (fn, ...args) => {
      expect(fn).toBe("menuRequest");
      reqPath = args[0]!;
      expect(reqPath).toBe(join(menuDir(), "abc.json"));
      expect(JSON.parse(readFileSync(reqPath, "utf8"))).toEqual({ mode: "input", prompt: "Q" });
      expect(statSync(reqPath).mode & 0o777).toBe(0o600);
      expect(statSync(menuDir()).mode & 0o777).toBe(0o700);
      return "ok";
    },
  });
  expect(out).toEqual({ kind: "chosen", text: "typed" });
  expect(sleeps).toBe(2);
  expect(readdirSync(menuDir())).toEqual([]);
});

test("requestMenu treats a missing or empty .out as cancel", async () => {
  for (const write of [false, true]) {
    let reqPath = "";
    const out = await requestMenu(buildMenuRequest("input", {}), {
      runtimeDir: runtime,
      sleep: noSleep,
      ipc: async (_fn, p) => {
        reqPath = p!;
        if (write) writeFileSync(reqPath.replace(/\.json$/, ".out"), "");
        writeFileSync(reqPath.replace(/\.json$/, ".done"), "");
        return "";
      },
    });
    expect(out).toEqual({ kind: "cancelled" });
    expect(readdirSync(menuDir())).toEqual([]);
  }
});

test("requestMenu reports an unreachable shell and cleans up", async () => {
  const out = await requestMenu(buildMenuRequest("input", {}), {
    runtimeDir: runtime,
    sleep: noSleep,
    ipc: async () => {
      throw new ShellIpcError("not-running", "the marchyo shell is not running");
    },
  });
  expect(out.kind).toBe("unreachable");
  expect(readdirSync(menuDir())).toEqual([]);
  expect((await requestMenu(buildMenuRequest("input", {}), { runtimeDir: "" })).kind).toBe(
    "unreachable",
  );
});

test("requestMenu gives up after the timeout and cleans up", async () => {
  let sleeps = 0;
  const out = await requestMenu(buildMenuRequest("input", {}), {
    runtimeDir: runtime,
    pollMs: 50,
    timeoutMs: 500,
    sleep: async () => {
      sleeps++;
    },
    ipc: async () => "",
  });
  expect(out).toEqual({ kind: "cancelled" });
  expect(sleeps).toBe(10);
  expect(readdirSync(menuDir())).toEqual([]);
});

function answer(text: string | null) {
  return async (_fn: string, p?: string) => {
    if (text !== null) writeFileSync(p!.replace(/\.json$/, ".out"), text);
    writeFileSync(p!.replace(/\.json$/, ".done"), "");
    return "";
  };
}

test("menu select prints the label, or label TAB subtext", async () => {
  const stdin = async () => "\u{f0e7}\tLock\nWi-Fi\tconnected\n";
  const plain = await capture(() =>
    runMenuSelect(rt, {}, { runtimeDir: runtime, sleep: noSleep, readStdin: stdin, ipc: answer("Lock\n") }),
  );
  expect(plain).toEqual({ code: 0, out: "Lock\n" });
  const sub = await capture(() =>
    runMenuSelect(rt, {}, {
      runtimeDir: runtime, sleep: noSleep, readStdin: stdin, ipc: answer("Wi-Fi\tconnected\n"),
    }),
  );
  expect(sub.out).toBe("Wi-Fi\tconnected\n");
});

test("menu select --multiple prints a JSON array and sends the request fields", async () => {
  let sent: unknown;
  const r = await capture(() =>
    runMenuSelect(
      rt,
      { multiple: true, prompt: "Pick", width: "300", maxheight: "200", selected: ["A"], onChange: '["notify-send"]', changeKey: "k" },
      {
        runtimeDir: runtime,
        sleep: noSleep,
        readStdin: async () => "A\nB\n",
        ipc: async (fn, p) => {
          sent = JSON.parse(readFileSync(p!, "utf8"));
          return answer("A\nB\n")(fn, p);
        },
      },
    ),
  );
  expect(r).toEqual({ code: 0, out: '["A","B"]\n' });
  expect(sent).toEqual({
    mode: "select",
    prompt: "Pick",
    rows: [{ label: "A" }, { label: "B" }],
    multiple: true,
    selected: ["A"],
    width: 300,
    maxHeight: 200,
    onChange: ["notify-send"],
    changeKey: "k",
  });
});

test("menu select exits 1 on cancel, 2 when the shell is unreachable", async () => {
  const base = { runtimeDir: runtime, sleep: noSleep, readStdin: async () => "A\n" };
  expect((await capture(() => runMenuSelect(rt, {}, { ...base, ipc: answer(null) }))).code).toBe(1);
  const down = async () => {
    throw new ShellIpcError("not-installed", "marchyo-shell is not installed");
  };
  expect((await capture(() => runMenuSelect(rt, {}, { ...base, ipc: down }))).code).toBe(2);
  expect((await capture(() => runMenuSelect(rt, { width: "x" }, { ...base, ipc: down }))).code).toBe(2);
  expect(
    (await capture(() => runMenuSelect(rt, { onChange: "nope" }, { ...base, ipc: down }))).code,
  ).toBe(2);
});

test("menu select --tui falls back to gum when the shell is unreachable", async () => {
  const down = async () => {
    throw new ShellIpcError("not-running", "x");
  };
  const r = await capture(() =>
    runMenuSelect(rt, { tui: true, multiple: true }, {
      runtimeDir: runtime,
      sleep: noSleep,
      ipc: down,
      readStdin: async () => "g\tA\tsub\nB\n",
      gum: async (rows) => [rows[0]!, rows[1]!],
    }),
  );
  expect(r).toEqual({ code: 0, out: '["A\\tsub","B"]\n' });
  const cancelled = await capture(() =>
    runMenuSelect(rt, { tui: true }, {
      runtimeDir: runtime, sleep: noSleep, ipc: down, readStdin: async () => "A\n", gum: async () => null,
    }),
  );
  expect(cancelled.code).toBe(1);
});

test("menu input prints the typed line, with a gum fallback", async () => {
  const r = await capture(() =>
    runMenuInput(rt, { prompt: "Name" }, { runtimeDir: runtime, sleep: noSleep, ipc: answer("bob\n") }),
  );
  expect(r).toEqual({ code: 0, out: "bob\n" });
  const down = async () => {
    throw new ShellIpcError("not-running", "x");
  };
  expect(
    (await capture(() => runMenuInput(rt, {}, { runtimeDir: runtime, sleep: noSleep, ipc: down }))).code,
  ).toBe(2);
  const tui = await capture(() =>
    runMenuInput(rt, { tui: true }, {
      runtimeDir: runtime, sleep: noSleep, ipc: down, gumLine: async () => "typed",
    }),
  );
  expect(tui).toEqual({ code: 0, out: "typed\n" });
  expect(existsSync(menuDir()) ? readdirSync(menuDir()) : []).toEqual([]);
});

test("menu sends openMenu with the normalised route and prints the reply", async () => {
  const calls: string[][] = [];
  const r = await capture(() =>
    runMenu(rt, "Appearance.Theme", {
      ipc: async (fn, ...args) => {
        calls.push([fn, ...args]);
        return "opened";
      },
    }),
  );
  expect(r).toEqual({ code: 0, out: "opened\n" });
  expect(calls).toEqual([["openMenu", "appearance.theme"]]);
  const root = await capture(() => runMenu(rt, undefined, { ipc: async (fn, ...a) => (calls.push([fn, ...a]), "") }));
  expect(root).toEqual({ code: 0, out: "" });
  expect(calls[1]).toEqual(["openMenu", ""]);
});

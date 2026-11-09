import { afterEach, beforeEach, expect, spyOn, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { type Runtime, i18nDir, loadRuntimeState } from "@marchyo/core";
import { changeRegistry } from "../src/changes.ts";
import { type LanguageDeps, runLanguage } from "../src/commands/language.ts";

const RT: Runtime = {
  format: "text",
  noColor: true,
  forceColor: false,
  plain: true,
  noAnimation: true,
  noInput: true,
  quiet: false,
  verbose: 0,
};
const JSON_RT: Runtime = { ...RT, format: "json" };

let dir = "";
let reloads = 0;

function deps(baked: string | null = "en"): LanguageDeps {
  return {
    dir: i18nDir(),
    statePath: join(dir, "runtime.json"),
    baked,
    reload: async () => {
      reloads += 1;
    },
  };
}

// Run `fn` with stdout and stderr captured, returning the combined text.
async function captured(fn: () => Promise<number>): Promise<{ code: number; out: string }> {
  const chunks: string[] = [];
  const grab = (c: string | Uint8Array): boolean => {
    chunks.push(String(c));
    return true;
  };
  const so = spyOn(process.stdout, "write").mockImplementation(grab);
  const se = spyOn(process.stderr, "write").mockImplementation(grab);
  try {
    const code = await fn();
    return { code, out: chunks.join("") };
  } finally {
    so.mockRestore();
    se.mockRestore();
  }
}

beforeEach(() => {
  dir = mkdtempSync(join(tmpdir(), "marchyo-language-"));
  reloads = 0;
});

afterEach(() => {
  rmSync(dir, { recursive: true, force: true });
});

test("the language override is registered for runtime restore", () => {
  expect(changeRegistry.has("language")).toBe(true);
});

test("show reports the baked default when no override is stored", async () => {
  const { code, out } = await captured(() => runLanguage(JSON_RT, undefined, {}, deps("fi")));
  expect(code).toBe(0);
  expect(JSON.parse(out)).toEqual({
    language: { code: "fi", name: "Suomi", source: "declarative" },
  });
  expect(reloads).toBe(0);
});

test("set stores a primitive runtime override and reloads the shell", async () => {
  const d = deps();
  const { code } = await captured(() => runLanguage(RT, "de", {}, d));
  expect(code).toBe(0);
  expect((await loadRuntimeState(d.statePath)).overrides.language).toBe("de");
  expect(reloads).toBe(1);

  const shown = await captured(() => runLanguage(JSON_RT, undefined, {}, d));
  expect(JSON.parse(shown.out).language).toEqual({
    code: "de",
    name: "Deutsch",
    source: "runtime",
  });
});

test("an unknown code is a usage error and stores nothing", async () => {
  const d = deps();
  const { code, out } = await captured(() => runLanguage(RT, "xx", {}, d));
  expect(code).toBe(2);
  expect(out).toContain("xx");
  expect(() => readFileSync(d.statePath)).toThrow();
  expect(reloads).toBe(0);
});

test("--revert drops the override and reloads the shell", async () => {
  const d = deps();
  await captured(() => runLanguage(RT, "de", {}, d));
  const { code } = await captured(() => runLanguage(RT, undefined, { revert: true }, d));
  expect(code).toBe(0);
  expect((await loadRuntimeState(d.statePath)).overrides.language).toBeUndefined();
  expect(reloads).toBe(2);
});

test("list marks the current language and counts the rest", async () => {
  const json = await captured(() => runLanguage(JSON_RT, "list", {}, deps("fi")));
  const rows = JSON.parse(json.out).languages as Array<{ code: string; current: boolean }>;
  expect(rows[0]?.code).toBe("en");
  expect(rows.filter((r) => r.current).map((r) => r.code)).toEqual(["fi"]);

  const text = await captured(() => runLanguage(RT, "list", {}, deps("fi")));
  expect(text.out).toContain("* fi");
  expect(text.out).toMatch(/\d+ languages/);
});

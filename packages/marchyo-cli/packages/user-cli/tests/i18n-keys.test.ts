import { describe, expect, test } from "bun:test";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { parseCatalog, tr } from "@marchyo/core";

const srcDir = join(import.meta.dir, "..", "src");
const catalogPath = join(import.meta.dir, "..", "..", "..", "..", "..", "shell", "i18n", "en", "cli.json");

function sources(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? sources(join(dir, e.name)) : /\.tsx?$/.test(e.name) ? [join(dir, e.name)] : [],
  );
}

describe("CLI message keys", () => {
  const english = parseCatalog(readFileSync(catalogPath, "utf8"));
  const used = new Set<string>();
  for (const file of sources(srcDir)) {
    for (const m of readFileSync(file, "utf8").matchAll(/\btrn?\(\s*"([a-zA-Z0-9.]+)"/g)) {
      used.add(m[1]!);
    }
  }

  test("every key used by the commands exists in the English catalog", () => {
    expect(used.size).toBeGreaterThan(100);
    expect([...used].filter((k) => !Object.hasOwn(english, k))).toEqual([]);
  });

  test("tr substitutes holes in English", () => {
    expect(tr("language.invalid", "xx")).toBe('Unknown language "xx"');
  });
});

import { describe, expect, test } from "bun:test";
import { createRequire } from "node:module";
import { copyFileSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  type Locales,
  bakedLanguage,
  i18nDir,
  languageOverride,
  loadLocales,
  makeTranslator,
  pluralCategory,
  resolveLanguage,
  substitute,
  translate,
  translatePlural,
} from "../src/i18n.ts";

const require = createRequire(import.meta.url);
const shellI18n = require("../../../../../shell/Commons/I18n.js") as {
  category: (code: string, count: number) => string;
};

describe("translate", () => {
  const en = { a: "A", b: "B %1", n: { one: "%1 file", other: "%1 files" } };
  const fi = { a: "Ä" };

  test("falls back per key: language, English, then the key", () => {
    expect(translate(fi, en, "a")).toBe("Ä");
    expect(translate(fi, en, "b", [7])).toBe("B 7");
    expect(translate(fi, en, "missing.key")).toBe("missing.key");
  });

  test("an empty translation falls back to English", () => {
    expect(translate({ a: "" }, en, "a")).toBe("A");
  });

  test("a plural entry reads as its other form", () => {
    expect(translate({}, en, "n", [2])).toBe("2 files");
  });

  test("keys named like Object.prototype members are plain misses", () => {
    expect(translate({}, {}, "toString")).toBe("toString");
  });
});

describe("substitute", () => {
  test("replaces holes by position and leaves unmatched ones", () => {
    expect(substitute("%2 %1 %2", ["x", "y"])).toBe("y x y");
    expect(substitute("%1% done", [50])).toBe("50% done");
    expect(substitute("%3", ["x"])).toBe("%3");
    expect(substitute("%1", ["%2", "z"])).toBe("%2");
  });
});

describe("translatePlural", () => {
  const en = { n: { one: "%1 file", other: "%1 files" } };
  const ru = { n: { one: "%1 файл", few: "%1 файла", many: "%1 файлов", other: "%1 файла" } };

  test("uses the language rules for a translated entry", () => {
    expect(translatePlural(ru, en, "ru", "n", 1, [1])).toBe("1 файл");
    expect(translatePlural(ru, en, "ru", "n", 3, [3])).toBe("3 файла");
    expect(translatePlural(ru, en, "ru", "n", 11, [11])).toBe("11 файлов");
  });

  test("uses English rules for an English fallback entry", () => {
    expect(translatePlural({}, en, "ru", "n", 3, [3])).toBe("3 files");
    expect(translatePlural({}, en, "ru", "nope", 3, [3])).toBe("nope");
  });
});

describe("pluralCategory", () => {
  // Every code with its own branch in the plural rules (only English ships a
  // catalog, but the rules stay in step for when translations return).
  const codes = [
    "en", "fi", "de", "ja", "ko", "zh-CN", "zh-TW", "th", "vi", "id", "ms",
    "hi", "bn", "fa", "si", "fr", "pt-BR", "ca", "es-MX", "it", "pt", "fil",
    "is", "cs", "sk", "pl", "ru", "uk", "hr", "sr", "sl", "lt", "lv", "ro",
    "ar", "he", "ga",
  ];

  test("agrees with shell/Commons/I18n.js for every rule set", () => {
    const counts = [...Array.from({ length: 1001 }, (_, i) => i), 1000000, 2000000];
    for (const code of codes) {
      for (const n of counts) {
        expect(pluralCategory(code, n)).toBe(shellI18n.category(code, n));
      }
    }
  });
});

describe("resolveLanguage", () => {
  const registry = { en: {}, fi: {}, de: {} } as unknown as Locales;

  test("a known override wins over the baked default", () => {
    expect(resolveLanguage("de", "fi", registry)).toBe("de");
  });

  test("an unknown override falls through to the baked default, then English", () => {
    expect(resolveLanguage("xx", "fi", registry)).toBe("fi");
    expect(resolveLanguage("xx", "yy", registry)).toBe("en");
    expect(resolveLanguage(null, null, registry)).toBe("en");
    expect(resolveLanguage("toString", null, registry)).toBe("en");
  });
});

describe("catalog directory", () => {
  test("resolves the source tree catalogs when nothing else is set", () => {
    const dir = i18nDir({}, "/nonexistent/bin/marchyo", null);
    expect(dir).not.toBeNull();
    expect(Object.keys(loadLocales(dir))).toContain("en");
  });

  test("MARCHYO_I18N_DIR wins", () => {
    const dir = mkdtempSync(join(tmpdir(), "marchyo-i18n-"));
    try {
      writeFileSync(join(dir, "locales.json"), "{}");
      expect(i18nDir({ MARCHYO_I18N_DIR: dir }, "/x/bin/marchyo", null)).toBe(dir);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("a translation layers over the real English cli catalog", () => {
    const real = i18nDir();
    expect(real).not.toBeNull();
    const dir = mkdtempSync(join(tmpdir(), "marchyo-i18n-"));
    try {
      // The shipped English catalog plus a synthetic Finnish one.
      mkdirSync(join(dir, "en"));
      mkdirSync(join(dir, "fi"));
      copyFileSync(join(real as string, "en", "cli.json"), join(dir, "en", "cli.json"));
      writeFileSync(
        join(dir, "fi", "cli.json"),
        JSON.stringify({ "language.listCount": { one: "%1 kieli", other: "%1 kieltä" } }),
      );
      const tr = makeTranslator(dir, "fi");
      expect(tr.t("language.current", "fi", "Suomi")).toBe("Language: fi (Suomi)");
      expect(tr.tn("language.listCount", 1, 1)).toBe("1 kieli");
      expect(tr.tn("language.listCount", 3, 3)).toBe("3 kieltä");
      expect(tr.t("no.such.key")).toBe("no.such.key");
      expect(makeTranslator(dir, "en").tn("language.listCount", 3, 3)).toBe("3 languages");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("without any catalogs a key answers as itself", () => {
    expect(makeTranslator(null, "fi").t("language.current")).toBe("language.current");
  });
});

describe("baked and override language", () => {
  test("bakedLanguage reads the generated Config.qml property", () => {
    const dir = mkdtempSync(join(tmpdir(), "marchyo-config-"));
    try {
      const qml = join(dir, "Config.qml");
      writeFileSync(qml, 'QtObject {\n  readonly property string language: "fi"\n}\n');
      expect(bakedLanguage(qml)).toBe("fi");
      writeFileSync(qml, "QtObject {}\n");
      expect(bakedLanguage(qml)).toBeNull();
      expect(bakedLanguage(null)).toBeNull();
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("languageOverride reads the primitive from runtime.json", async () => {
    const dir = mkdtempSync(join(tmpdir(), "marchyo-runtime-"));
    try {
      const path = join(dir, "runtime.json");
      expect(await languageOverride(path)).toBeNull();
      writeFileSync(path, JSON.stringify({ schemaVersion: 1, overrides: { language: "de" } }));
      expect(await languageOverride(path)).toBe("de");
      writeFileSync(path, JSON.stringify({ schemaVersion: 1, overrides: { language: 3 } }));
      expect(await languageOverride(path)).toBeNull();
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});

// Unit tests for shell/Commons/I18n.js and the shipped catalogs in shell/i18n.
//
// Run: node tests/shell/i18n-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const shellDir = path.join(__dirname, "..", "..", "shell");
const I18n = require(path.join(shellDir, "Commons", "I18n.js"));
const i18nDir = path.join(shellDir, "i18n");

let passed = 0;

function test(name, fn) {
  try {
    fn();
  } catch (error) {
    console.error("not ok - " + name);
    console.error(String(error.message).replace(/^/gm, "    "));
    process.exit(1);
  }
  passed++;
  console.log("ok - " + name);
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

test("the module exports its whole public surface to Node", () => {
  assert.deepEqual(Object.keys(I18n).sort(), [
    "category",
    "formatNumber",
    "parseCatalog",
    "pick",
    "resolveLanguage",
    "substitute",
    "t",
    "tn",
  ]);
});

test("holes are replaced by position, once, and unmatched holes survive", () => {
  assert.equal(I18n.substitute("%1 of %2", ["a", 3]), "a of 3");
  assert.equal(I18n.substitute("%2 %1 %2", ["x", "y"]), "y x y");
  assert.equal(I18n.substitute("%1% (full)", [80]), "80% (full)");
  assert.equal(I18n.substitute("%3 missing", ["x"]), "%3 missing");
  assert.equal(I18n.substitute("%1", ["%2", "no"]), "%2");
  assert.equal(I18n.substitute("plain", undefined), "plain");
});

test("t falls back per key: language, then English, then the key", () => {
  const en = { a: "A", b: "B" };
  const fi = { a: "Ä" };
  assert.equal(I18n.t(fi, en, "a", []), "Ä");
  assert.equal(I18n.t(fi, en, "b", []), "B");
  assert.equal(I18n.t(fi, en, "missing.key", []), "missing.key");
  assert.equal(I18n.t({ a: "" }, en, "a", []), "A");
  assert.equal(I18n.t({}, { h: "%1 and %2" }, "h", [1, 2]), "1 and 2");
});

test("tn picks the plural form by the language rules", () => {
  const en = { n: { one: "%1 file", other: "%1 files" } };
  assert.equal(I18n.tn({}, en, "en", "n", 1, [1]), "1 file");
  assert.equal(I18n.tn({}, en, "en", "n", 0, [0]), "0 files");
  assert.equal(I18n.tn({}, en, "en", "n", 5, [5]), "5 files");
  const ru = { n: { one: "%1 файл", few: "%1 файла", many: "%1 файлов", other: "%1 файла" } };
  assert.equal(I18n.tn(ru, en, "ru", "n", 1, [1]), "1 файл");
  assert.equal(I18n.tn(ru, en, "ru", "n", 3, [3]), "3 файла");
  assert.equal(I18n.tn(ru, en, "ru", "n", 11, [11]), "11 файлов");
  assert.equal(I18n.tn(ru, en, "ru", "n", 21, [21]), "21 файл");
});

test("tn uses English rules for an English fallback entry and the key when absent", () => {
  const en = { n: { one: "%1 file", other: "%1 files" } };
  assert.equal(I18n.tn({}, en, "ru", "n", 3, [3]), "3 files");
  assert.equal(I18n.tn({}, en, "ru", "nope", 3, [3]), "nope");
});

test("a plural entry missing a category falls back to its other form", () => {
  assert.equal(I18n.pick({ other: "x" }, "pl", 3), "x");
  assert.equal(I18n.pick({ one: "o" }, "en", 5), undefined);
  assert.equal(I18n.pick("plain", "ja", 9), "plain");
});

test("plural categories match CLDR for representative languages", () => {
  const cases = [
    ["en", 1, "one"],
    ["en", 2, "other"],
    ["fi", 1, "one"],
    ["fi", 0, "other"],
    ["fr", 0, "one"],
    ["fr", 2, "other"],
    ["de", 1, "one"],
    ["ja", 1, "other"],
    ["pl", 1, "one"],
    ["pl", 2, "few"],
    ["pl", 5, "many"],
    ["pl", 12, "many"],
    ["pl", 22, "few"],
    ["ru", 21, "one"],
    ["ru", 24, "few"],
    ["ru", 25, "many"],
    ["cs", 3, "few"],
    ["cs", 5, "other"],
    ["sl", 101, "one"],
    ["sl", 102, "two"],
    ["ar", 0, "zero"],
    ["ar", 2, "two"],
    ["ar", 7, "few"],
    ["ar", 15, "many"],
    ["ar", 100, "other"],
    ["he", 2, "two"],
    ["lv", 10, "zero"],
    ["lt", 12, "other"],
    ["ro", 0, "few"],
  ];
  for (const [code, n, want] of cases) {
    assert.equal(I18n.category(code, n), want, code + " " + n);
  }
});

test("formatNumber uses the locale decimal separator and digits", () => {
  assert.equal(I18n.formatNumber(13.14, 1, ",", "0"), "13,1");
  assert.equal(I18n.formatNumber(13.14, 1, ".", "0"), "13.1");
  assert.equal(I18n.formatNumber(7, 1, ",", "0"), "7,0");
  assert.equal(I18n.formatNumber(2.5, undefined, ",", "0"), "2,5");
  assert.equal(I18n.formatNumber(12, 0, ".", "০"), "১২");
  assert.equal(I18n.formatNumber(NaN, 1, ",", "0"), "NaN");
});

test("resolveLanguage prefers a known override, then the baked default, then English", () => {
  const registry = { en: {}, fi: {}, de: {} };
  assert.equal(I18n.resolveLanguage("de", "fi", registry), "de");
  assert.equal(I18n.resolveLanguage("", "fi", registry), "fi");
  assert.equal(I18n.resolveLanguage("xx", "fi", registry), "fi");
  assert.equal(I18n.resolveLanguage("xx", "yy", registry), "en");
  assert.equal(I18n.resolveLanguage(undefined, undefined, registry), "en");
  assert.equal(I18n.resolveLanguage("toString", "", registry), "en");
});

test("parseCatalog yields an empty catalog for anything unusable", () => {
  assert.deepEqual(I18n.parseCatalog(""), {});
  assert.deepEqual(I18n.parseCatalog("not json"), {});
  assert.deepEqual(I18n.parseCatalog("[1]"), {});
  assert.deepEqual(I18n.parseCatalog('{"a":"b"}'), { a: "b" });
});

const CATALOGS = ["shell", "cli", "menu", "keybindings"];
const HOLE = /%(\d+)/g;

function holes(value) {
  const text = typeof value === "string" ? value : Object.values(value).join("\n");
  return [...new Set([...text.matchAll(HOLE)].map((m) => m[1]))].sort();
}

test("every catalog parses and holds only strings or plural objects", () => {
  const registry = readJson(path.join(i18nDir, "locales.json"));
  for (const code of fs.readdirSync(i18nDir)) {
    const dir = path.join(i18nDir, code);
    if (!fs.statSync(dir).isDirectory()) continue;
    assert.ok(registry[code], "locale directory " + code + " is not in locales.json");
    for (const file of fs.readdirSync(dir)) {
      const name = file.replace(/\.json$/, "");
      assert.ok(CATALOGS.includes(name), "unexpected catalog " + code + "/" + file);
      const catalog = readJson(path.join(dir, file));
      for (const [key, value] of Object.entries(catalog)) {
        const ok =
          (typeof value === "string" && value.length > 0) ||
          (value !== null &&
            typeof value === "object" &&
            typeof value.other === "string" &&
            Object.values(value).every((v) => typeof v === "string"));
        assert.ok(ok, code + "/" + file + ": bad value for " + key);
      }
    }
  }
});

test("English ships every catalog and the registry lists English", () => {
  const registry = readJson(path.join(i18nDir, "locales.json"));
  assert.ok(registry.en);
  for (const name of CATALOGS) {
    assert.ok(fs.existsSync(path.join(i18nDir, "en", name + ".json")), "en/" + name + ".json");
  }
  for (const [code, entry] of Object.entries(registry)) {
    for (const field of ["name", "englishName", "formatLocale", "locale", "decimal", "zeroDigit"]) {
      assert.equal(typeof entry[field], "string", code + "." + field);
    }
  }
});

test("no translated key is absent from English and every hole set matches", () => {
  for (const code of fs.readdirSync(i18nDir)) {
    const dir = path.join(i18nDir, code);
    if (code === "en" || !fs.statSync(dir).isDirectory()) continue;
    for (const file of fs.readdirSync(dir)) {
      const english = readJson(path.join(i18nDir, "en", file));
      const catalog = readJson(path.join(dir, file));
      for (const [key, value] of Object.entries(catalog)) {
        assert.ok(key in english, code + "/" + file + ": " + key + " is not in en");
        assert.deepEqual(holes(value), holes(english[key]), code + "/" + file + ": holes of " + key);
      }
    }
  }
});

test("plural English entries carry one and other", () => {
  for (const name of CATALOGS) {
    const catalog = readJson(path.join(i18nDir, "en", name + ".json"));
    for (const [key, value] of Object.entries(catalog)) {
      if (typeof value === "string") continue;
      assert.equal(typeof value.one, "string", name + ": " + key + " needs one");
      assert.equal(typeof value.other, "string", name + ": " + key + " needs other");
    }
  }
});

function qmlFiles(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return entry.name === "compat" ? [] : qmlFiles(full);
    return entry.name.endsWith(".qml") ? [full] : [];
  });
}

test("every literal key the QML looks up exists in the English shell catalog", () => {
  const en = readJson(path.join(i18nDir, "en", "shell.json"));
  const missing = [];
  for (const file of qmlFiles(shellDir)) {
    const text = fs.readFileSync(file, "utf8");
    for (const m of text.matchAll(/I18n\.tn?\(\s*"([A-Za-z0-9.]+)"/g)) {
      const known = m[1].endsWith(".") ? Object.keys(en).some((k) => k.startsWith(m[1])) : m[1] in en;
      if (!known && !file.endsWith("harness.qml")) {
        missing.push(path.relative(shellDir, file) + ": " + m[1]);
      }
    }
  }
  assert.deepEqual(missing, []);
});

test("the seeded shell keys translate through the real lookup", () => {
  const en = readJson(path.join(i18nDir, "en", "shell.json"));
  const fi = readJson(path.join(i18nDir, "fi", "shell.json"));
  assert.equal(I18n.t(fi, en, "audio.title", []), fi["audio.title"]);
  assert.equal(I18n.t(fi, en, "audio.noOutput", []), "No output");
  assert.equal(I18n.t(fi, en, "power.charger", [65]), "Charger  65 W");
});

console.log("# " + passed + " passed");

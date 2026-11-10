import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { shellConfigQmlPath, shellShareDir } from "./shell-ipc.ts";
import { loadRuntimeState, runtimeStatePath } from "./runtime-state.ts";

// CLI side of the string layer. The lookup semantics mirror
// shell/Commons/I18n.js (the shell side): per-key English fallback, then the
// key; `%N` holes; `{one, other}` plural entries. Catalogs are the shell's
// shell/i18n tree: flat dotted keys per language and catalog name.

export type CatalogValue = string | Record<string, string>;
export type Catalog = Record<string, CatalogValue>;

export type LocaleEntry = {
  name: string;
  englishName: string;
  formatLocale: string;
  locale: string;
  decimal: string;
  zeroDigit: string;
  direction?: string;
};

export type Locales = Record<string, LocaleEntry>;

export const DEFAULT_LANGUAGE = "en";

function within(value: number, low: number, high: number): boolean {
  return value >= low && value <= high;
}

// CLDR cardinal plural category of a whole count; the table matches
// shell/Commons/I18n.js (tests/i18n.test.ts compares them).
export function pluralCategory(code: string, count: number): string {
  const n = Math.abs(Math.trunc(Number(count) || 0));
  const n10 = n % 10;
  const n100 = n % 100;
  const millions = n !== 0 && n % 1000000 === 0;
  switch (code) {
    case "ja":
    case "ko":
    case "zh-CN":
    case "zh-TW":
    case "th":
    case "vi":
    case "id":
    case "ms":
      return "other";
    case "hi":
    case "bn":
    case "fa":
    case "si":
      return n <= 1 ? "one" : "other";
    case "fr":
    case "pt-BR":
      return n <= 1 ? "one" : millions ? "many" : "other";
    case "ca":
    case "es-MX":
    case "it":
    case "pt":
      return n === 1 ? "one" : millions ? "many" : "other";
    case "fil":
      return n10 === 4 || n10 === 6 || n10 === 9 ? "other" : "one";
    case "is":
      return n10 === 1 && n100 !== 11 ? "one" : "other";
    case "cs":
    case "sk":
      return n === 1 ? "one" : within(n, 2, 4) ? "few" : "other";
    case "pl":
      if (n === 1) return "one";
      return within(n10, 2, 4) && !within(n100, 12, 14) ? "few" : "many";
    case "ru":
    case "uk":
      if (n10 === 1 && n100 !== 11) return "one";
      return within(n10, 2, 4) && !within(n100, 12, 14) ? "few" : "many";
    case "hr":
    case "sr":
      if (n10 === 1 && n100 !== 11) return "one";
      return within(n10, 2, 4) && !within(n100, 12, 14) ? "few" : "other";
    case "sl":
      if (n100 === 1) return "one";
      if (n100 === 2) return "two";
      return within(n100, 3, 4) ? "few" : "other";
    case "lt":
      if (within(n100, 11, 19)) return "other";
      return n10 === 1 ? "one" : n10 >= 2 ? "few" : "other";
    case "lv":
      if (n10 === 0 || within(n100, 11, 19)) return "zero";
      return n10 === 1 ? "one" : "other";
    case "ro":
      if (n === 1) return "one";
      return n === 0 || within(n100, 1, 19) ? "few" : "other";
    case "ar":
      if (n <= 2) return ["zero", "one", "two"][n]!;
      return within(n100, 3, 10) ? "few" : within(n100, 11, 99) ? "many" : "other";
    case "he":
      return n === 1 ? "one" : n === 2 ? "two" : "other";
    case "ga":
      if (n <= 2) return n === 0 ? "other" : n === 1 ? "one" : "two";
      return within(n, 3, 6) ? "few" : within(n, 7, 10) ? "many" : "other";
    default:
      return n === 1 ? "one" : "other";
  }
}

// The string for a count from an entry, or the entry itself when it is a
// plain string. Undefined when the entry gives nothing usable.
export function pickForm(
  entry: CatalogValue | undefined,
  code: string,
  count: number,
): string | undefined {
  if (typeof entry === "string") return entry.length > 0 ? entry : undefined;
  if (entry === null || typeof entry !== "object") return undefined;
  const form = entry[pluralCategory(code, count)];
  if (typeof form === "string" && form.length > 0) return form;
  return typeof entry.other === "string" && entry.other.length > 0
    ? entry.other
    : undefined;
}

export function substitute(text: string, args: ReadonlyArray<unknown>): string {
  return text.replace(/%(\d+)/g, (whole, index: string) => {
    const i = Number(index) - 1;
    return i >= 0 && i < args.length ? String(args[i]) : whole;
  });
}

type Found = { value: CatalogValue; english: boolean };

function find(language: Catalog, english: Catalog, key: string): Found | null {
  const own = Object.hasOwn(language, key) ? language[key] : undefined;
  if (pickForm(own, "en", 1) !== undefined) return { value: own!, english: false };
  const fallback = Object.hasOwn(english, key) ? english[key] : undefined;
  if (pickForm(fallback, "en", 1) !== undefined) {
    return { value: fallback!, english: true };
  }
  return null;
}

export function translate(
  language: Catalog,
  english: Catalog,
  key: string,
  args: ReadonlyArray<unknown> = [],
): string {
  const found = find(language, english, key);
  if (found === null) return key;
  return substitute(pickForm(found.value, "en", 2)!, args);
}

export function translatePlural(
  language: Catalog,
  english: Catalog,
  code: string,
  key: string,
  count: number,
  args: ReadonlyArray<unknown> = [],
): string {
  const found = find(language, english, key);
  if (found === null) return key;
  return substitute(
    pickForm(found.value, found.english ? "en" : code, count)!,
    args,
  );
}

export function parseCatalog(raw: string): Catalog {
  try {
    const parsed: unknown = JSON.parse(raw === "" ? "{}" : raw);
    return parsed !== null && typeof parsed === "object" && !Array.isArray(parsed)
      ? (parsed as Catalog)
      : {};
  } catch {
    return {};
  }
}

export function resolveLanguage(
  override: unknown,
  baked: unknown,
  registry: Locales,
): string {
  for (const candidate of [override, baked]) {
    const code = typeof candidate === "string" ? candidate.trim() : "";
    if (code !== "" && Object.hasOwn(registry, code)) return code;
  }
  return DEFAULT_LANGUAGE;
}

// The catalog directory: MARCHYO_I18N_DIR, then the one installed beside the
// binary, then the shell package's, then the source tree (dev runs).
export function i18nDir(
  env: NodeJS.ProcessEnv = process.env,
  execPath: string = process.execPath,
  shellShare: string | null = shellShareDir(env.PATH ?? ""),
): string | null {
  const candidates = [
    env.MARCHYO_I18N_DIR,
    join(dirname(dirname(execPath)), "share", "marchyo", "i18n"),
    shellShare === null ? undefined : join(shellShare, "i18n"),
    join(
      dirname(fileURLToPath(import.meta.url)),
      "..", "..", "..", "..", "..", "shell", "i18n",
    ),
  ];
  for (const dir of candidates) {
    if (dir !== undefined && dir !== "" && existsSync(join(dir, "locales.json"))) {
      return dir;
    }
  }
  return null;
}

function readText(path: string): string {
  try {
    return readFileSync(path, "utf8");
  } catch {
    return "";
  }
}

export function loadLocales(dir: string | null = i18nDir()): Locales {
  if (dir === null) return {};
  return parseCatalog(readText(join(dir, "locales.json"))) as unknown as Locales;
}

export function loadCatalog(
  dir: string | null,
  code: string,
  name: string,
): Catalog {
  if (dir === null) return {};
  return parseCatalog(readText(join(dir, code, `${name}.json`)));
}

// The baked default language, read from the store shell's generated
// Commons/Config.qml. Null when the shell is not installed.
export function bakedLanguage(
  qmlPath: string | null = shellConfigQmlPath(),
): string | null {
  if (qmlPath === null) return null;
  const m = readText(qmlPath).match(/readonly property string language:\s*"([^"]*)"/);
  return m?.[1] ?? null;
}

export async function languageOverride(
  path: string = runtimeStatePath(),
): Promise<string | null> {
  const value = (await loadRuntimeState(path)).overrides.language;
  return typeof value === "string" && value !== "" ? value : null;
}

export type Translator = {
  language: string;
  t: (key: string, ...args: unknown[]) => string;
  tn: (key: string, count: number, ...args: unknown[]) => string;
};

export function makeTranslator(
  dir: string | null,
  language: string,
  name = "cli",
): Translator {
  const english = loadCatalog(dir, DEFAULT_LANGUAGE, name);
  const own = language === DEFAULT_LANGUAGE ? {} : loadCatalog(dir, language, name);
  return {
    language,
    t: (key, ...args) => translate(own, english, key, args),
    tn: (key, count, ...args) =>
      translatePlural(own, english, language, key, count, args),
  };
}

// The translator for the effective language: runtime override, else the
// shell's baked default, else English.
export async function cliTranslator(
  dir: string | null = i18nDir(),
  statePath: string = runtimeStatePath(),
): Promise<Translator> {
  const language = resolveLanguage(
    await languageOverride(statePath),
    bakedLanguage(),
    loadLocales(dir),
  );
  return makeTranslator(dir, language);
}

function languageOverrideSync(path: string = runtimeStatePath()): string | null {
  try {
    const state = JSON.parse(readFileSync(path, "utf8")) as {
      overrides?: { language?: unknown };
    };
    const value = state.overrides?.language;
    return typeof value === "string" && value !== "" ? value : null;
  } catch {
    return null;
  }
}

const shared = new Map<string, Translator>();

function sharedTranslator(name: string): Translator {
  let found = shared.get(name);
  if (found === undefined) {
    const dir = i18nDir();
    found = makeTranslator(
      dir,
      resolveLanguage(languageOverrideSync(), bakedLanguage(), loadLocales(dir)),
      name,
    );
    shared.set(name, found);
  }
  return found;
}

// Process-wide lookup for user-visible runtime messages (errors, notices,
// notifications). The language resolves once per process.
export function tr(key: string, ...args: unknown[]): string {
  return sharedTranslator("cli").t(key, ...args);
}

export function trn(key: string, count: number, ...args: unknown[]): string {
  return sharedTranslator("cli").tn(key, count, ...args);
}

// A menu label in the effective language; the English label when the menu
// catalog has no entry for it.
export function menuLabel(english: string): string {
  const key = `menu.${english
    .replace(/[^A-Za-z0-9]+(.)?/g, (_, c: string | undefined) => (c ?? "").toUpperCase())
    .replace(/^./, (c) => c.toLowerCase())}`;
  const found = sharedTranslator("menu").t(key);
  return found === key ? english : found;
}

export function resetSharedTranslator(): void {
  shared.clear();
}

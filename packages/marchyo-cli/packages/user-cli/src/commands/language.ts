import {
  type ChangeSpec,
  type Locales,
  type Runtime,
  type Translator,
  applyChange,
  bakedLanguage,
  data,
  i18nDir,
  languageOverride,
  loadLocales,
  makeTranslator,
  resolveLanguage,
  runtimeStatePath,
  shellIpc,
  usageError,
} from "@marchyo/core";

// `marchyo language [code|list]`: the display language of marchyo's own UI
// (the shell and this CLI). A runtime override on top of marchyo.language; the
// system LANG changes only on rebuild.

export const languageChangeBase: ChangeSpec = {
  key: "language",
  runtimeApply: async (ctx) => {
    if (typeof ctx.value !== "string" || ctx.value === "") {
      throw new Error("language needs a language code");
    }
    return ctx.value;
  },
  runtimeRevert: async () => {},
};

export type LanguageDeps = {
  dir: string | null;
  statePath: string;
  baked: string | null;
  // Nudge the running shell to re-read its language; failures are ignored.
  reload: () => Promise<void>;
};

function defaultDeps(): LanguageDeps {
  return {
    dir: i18nDir(),
    statePath: runtimeStatePath(),
    baked: bakedLanguage(),
    reload: async () => {
      await shellIpc("reload").catch(() => {});
    },
  };
}

type Current = { language: string; source: "runtime" | "declarative" };

async function current(deps: LanguageDeps, locales: Locales): Promise<Current> {
  const override = await languageOverride(deps.statePath);
  const language = resolveLanguage(override, deps.baked, locales);
  const fromOverride = override !== null && resolveLanguage(override, null, locales) === override;
  return { language, source: fromOverride ? "runtime" : "declarative" };
}

function nameOf(locales: Locales, code: string): string {
  return locales[code]?.name ?? code;
}

function showCurrent(rt: Runtime, now: Current, locales: Locales, tr: Translator): number {
  const name = nameOf(locales, now.language);
  data(rt, { language: { code: now.language, name, source: now.source } }, () =>
    tr.t("language.current", now.language, name),
  );
  return 0;
}

function showList(rt: Runtime, now: Current, locales: Locales, tr: Translator): number {
  const rows = Object.entries(locales)
    .map(([code, e]) => ({
      code,
      name: e.name,
      englishName: e.englishName,
      current: code === now.language,
    }))
    .sort((a, b) =>
      a.code === "en" ? -1 : b.code === "en" ? 1 : a.englishName.localeCompare(b.englishName),
    );
  data(rt, { languages: rows }, () => {
    const width = Math.max(...rows.map((r) => r.code.length));
    const lines = rows.map(
      (r) =>
        `${r.current ? "*" : " "} ${r.code.padEnd(width)}  ${r.name} (${r.englishName})`,
    );
    return [...lines, "", tr.tn("language.listCount", rows.length, rows.length)].join("\n");
  });
  return 0;
}

export type LanguageOpts = { revert?: boolean };

export async function runLanguage(
  rt: Runtime,
  arg: string | undefined,
  opts: LanguageOpts,
  deps: LanguageDeps = defaultDeps(),
): Promise<number> {
  const locales = loadLocales(deps.dir);
  const now = await current(deps, locales);
  const tr = makeTranslator(deps.dir, now.language);

  if (opts.revert) {
    const code = await applyChange(rt, languageChangeBase, {
      mode: "revert",
      runtimePath: deps.statePath,
    });
    if (code === 0) await deps.reload();
    return code;
  }
  if (arg === undefined) return showCurrent(rt, now, locales, tr);
  if (arg === "list") return showList(rt, now, locales, tr);
  if (!Object.hasOwn(locales, arg)) {
    return usageError(rt, tr.t("language.invalid", arg), tr.t("language.invalidHint"));
  }
  const code = await applyChange(rt, languageChangeBase, {
    mode: "runtime",
    value: arg,
    runtimePath: deps.statePath,
  });
  if (code === 0) await deps.reload();
  return code;
}

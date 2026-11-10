import { afterAll, beforeAll, expect, test } from "bun:test";
import {
  chmodSync,
  copyFileSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { i18nDir } from "@marchyo/core";

let dir = "";

beforeAll(() => {
  dir = mkdtempSync(join(tmpdir(), "menu-i18n-"));
  writeFileSync(
    join(dir, "gum"),
    '#!/bin/sh\nprintf "%s\\n" "$@" > "$GUM_ARGS"\nprintf "%s\\n" "$GUM_PICK"\n',
  );
  chmodSync(join(dir, "gum"), 0o755);
  mkdirSync(join(dir, "marchyo"), { recursive: true });
  writeFileSync(
    join(dir, "marchyo", "runtime.json"),
    JSON.stringify({ schemaVersion: 1, overrides: { language: "fi" } }),
  );
  // Only English ships: a synthetic Finnish menu catalog over the real English.
  const real = i18nDir();
  if (real === null) throw new Error("the shell/i18n catalogs are missing");
  const i18n = join(dir, "i18n");
  mkdirSync(join(i18n, "en"), { recursive: true });
  mkdirSync(join(i18n, "fi"), { recursive: true });
  copyFileSync(join(real, "en", "menu.json"), join(i18n, "en", "menu.json"));
  writeFileSync(join(i18n, "fi", "menu.json"), JSON.stringify({ "menu.suspend": "Lepotila" }));
  writeFileSync(
    join(i18n, "locales.json"),
    JSON.stringify({
      en: { name: "English", englishName: "English", formatLocale: "en-US", locale: "en_US.UTF-8", decimal: ".", zeroDigit: "0" },
      fi: { name: "Suomi", englishName: "Finnish", formatLocale: "fi-FI", locale: "fi_FI.UTF-8", decimal: ",", zeroDigit: "0" },
    }),
  );
});

afterAll(() => rmSync(dir, { recursive: true, force: true }));

// A child process, because Bun resolves `gum` against the PATH it started with.
test("a translated gum selection maps back to the English option", async () => {
  const proc = Bun.spawn(["bun", join(import.meta.dir, "menu-i18n-child.ts")], {
    env: {
      ...process.env,
      PATH: `${dir}:${process.env.PATH}`,
      XDG_STATE_HOME: dir,
      MARCHYO_I18N_DIR: join(dir, "i18n"),
      GUM_ARGS: join(dir, "args"),
      GUM_PICK: "Lepotila",
    },
    stdout: "pipe",
    stderr: "inherit",
  });
  const out = await new Response(proc.stdout).text();
  await proc.exited;
  expect(out.trim()).toBe("Suspend");
  expect(readFileSync(join(dir, "args"), "utf8")).toContain("Lepotila");
});

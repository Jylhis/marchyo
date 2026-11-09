import { afterAll, beforeAll, expect, test } from "bun:test";
import {
  chmodSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

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
});

afterAll(() => rmSync(dir, { recursive: true, force: true }));

// A child process, because Bun resolves `gum` against the PATH it started with.
test("a translated gum selection maps back to the English option", async () => {
  const proc = Bun.spawn(["bun", join(import.meta.dir, "menu-i18n-child.ts")], {
    env: {
      ...process.env,
      PATH: `${dir}:${process.env.PATH}`,
      XDG_STATE_HOME: dir,
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

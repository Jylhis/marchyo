import { mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { afterAll, beforeAll } from "bun:test";
import { resetSharedTranslator } from "@marchyo/core";
import { join } from "node:path";

// A busctl on PATH that records each `call` argv (NUL separated, one file per
// call), answers `status` with success and prints a Notify reply of `u 42`.
export type FakeBusctl = {
  dir: string;
  env: Record<string, string>;
  calls: () => string[][];
};

export function fakeBusctl(statusExit = 0): FakeBusctl {
  const dir = join(tmpdir(), `marchyo-busctl-${Date.now()}-${Math.random().toString(36).slice(2)}`);
  mkdirSync(join(dir, "bin"), { recursive: true });
  mkdirSync(join(dir, "calls"), { recursive: true });
  mkdirSync(join(dir, "runtime"), { recursive: true, mode: 0o700 });
  const script = `#!/bin/sh
if [ "$2" = "status" ]; then exit ${statusExit}; fi
n=$(ls "${dir}/calls" | wc -l)
printf '%s\\0' "$@" > "${dir}/calls/$n"
echo "u 42"
`;
  writeFileSync(join(dir, "bin", "busctl"), script, { mode: 0o755 });
  return {
    dir,
    env: {
      PATH: `${join(dir, "bin")}:${process.env.PATH}`,
      XDG_RUNTIME_DIR: join(dir, "runtime"),
      XDG_STATE_HOME: join(dir, "state"),
    },
    calls: () =>
      readdirSync(join(dir, "calls"))
        .sort((a, b) => Number(a) - Number(b))
        .map((f) => readFileSync(join(dir, "calls", f), "utf8").split("\0").slice(0, -1)),
  };
}

// The source catalogs, so messages resolve even where a (possibly older)
// installed shell package is on PATH. Children inherit the variable.
export function useSourceCatalog(): void {
  const dir = join(import.meta.dir, "..", "..", "..", "..", "..", "shell", "i18n");
  let before: string | undefined;
  beforeAll(() => {
    before = process.env.MARCHYO_I18N_DIR;
    process.env.MARCHYO_I18N_DIR = dir;
    resetSharedTranslator();
  });
  afterAll(() => {
    if (before === undefined) delete process.env.MARCHYO_I18N_DIR;
    else process.env.MARCHYO_I18N_DIR = before;
    resetSharedTranslator();
  });
}

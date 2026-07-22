import { describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  type ChangeSpec,
  applyChange,
  parseChangeFlags,
} from "../src/apply.ts";
import { buildRuntime } from "../src/runtime.ts";
import { loadRuntimeState, setOverride } from "../src/runtime-state.ts";
import { type State } from "../src/state.ts";

const rt = buildRuntime({ quiet: true }, {}, false);

type Recorded = { runtimeApplies: number; runtimeReverts: number };

function makeSpec(
  overrides: Partial<ChangeSpec> = {},
): { spec: ChangeSpec; calls: Recorded } {
  const calls: Recorded = { runtimeApplies: 0, runtimeReverts: 0 };
  const spec: ChangeSpec = {
    key: "toggle.test",
    runtimeApply: async () => {
      calls.runtimeApplies += 1;
      return true;
    },
    runtimeRevert: async () => {
      calls.runtimeReverts += 1;
    },
    ...overrides,
  };
  return { spec, calls };
}

function tempPaths(): {
  dir: string;
  runtimePath: string;
  statePath: string;
} {
  const dir = mkdtempSync(join(tmpdir(), "marchyo-apply-"));
  return {
    dir,
    runtimePath: join(dir, "runtime.json"),
    statePath: join(dir, "cli-state.json"),
  };
}

// Common state-persistence legs used by specs that support --apply/--revert.
const persistable = {
  stateWrite: (prev: State, _value: unknown): State => ({
    ...prev,
    theme: { ...prev.theme, variant: "light" as const },
  }),
  stateDelete: (prev: State): State => {
    const next = { ...prev };
    delete next.theme;
    return next;
  },
};

describe("parseChangeFlags", () => {
  test("maps flags to modes", () => {
    expect(parseChangeFlags(rt, {})).toBe("runtime");
    expect(parseChangeFlags(rt, { apply: true })).toBe("apply");
    expect(parseChangeFlags(rt, { revert: true })).toBe("revert");
  });

  test("both flags is a usage error", () => {
    expect(parseChangeFlags(rt, { apply: true, revert: true })).toBe(2);
  });
});

describe("applyChange mode=runtime", () => {
  test("applies live and records the override", async () => {
    const { dir, runtimePath } = tempPaths();
    try {
      const { spec, calls } = makeSpec();
      const code = await applyChange(rt, spec, { mode: "runtime", runtimePath });
      expect(code).toBe(0);
      expect(calls.runtimeApplies).toBe(1);
      const state = await loadRuntimeState(runtimePath);
      expect(state.overrides["toggle.test"]).toBe(true);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});

describe("applyChange mode=apply", () => {
  test("without stateWrite is a usage error", async () => {
    const { dir, runtimePath } = tempPaths();
    try {
      const { spec } = makeSpec();
      const code = await applyChange(rt, spec, { mode: "apply", runtimePath });
      expect(code).toBe(2);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("persists, rebuilds, and clears the override on success", async () => {
    const { dir, runtimePath, statePath } = tempPaths();
    try {
      const { spec, calls } = makeSpec(persistable);
      let rebuilds = 0;
      const code = await applyChange(rt, spec, {
        mode: "apply",
        runtimePath,
        systemStatePath: join(dir, "missing-system.json"),
        userPath: join(dir, "missing-user.json"),
        stateWritePath: statePath,
        rebuild: async () => {
          rebuilds += 1;
          return 0;
        },
      });
      expect(code).toBe(0);
      expect(calls.runtimeApplies).toBe(1);
      expect(rebuilds).toBe(1);
      const persisted = await Bun.file(statePath).json();
      expect(persisted.theme.variant).toBe("light");
      const state = await loadRuntimeState(runtimePath);
      expect(state.overrides["toggle.test"]).toBeUndefined();
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("keeps the override when the rebuild fails", async () => {
    const { dir, runtimePath, statePath } = tempPaths();
    try {
      const { spec } = makeSpec(persistable);
      const code = await applyChange(rt, spec, {
        mode: "apply",
        runtimePath,
        systemStatePath: join(dir, "missing-system.json"),
        userPath: join(dir, "missing-user.json"),
        stateWritePath: statePath,
        rebuild: async () => 1,
      });
      expect(code).toBe(1);
      const state = await loadRuntimeState(runtimePath);
      expect(state.overrides["toggle.test"]).toBe(true);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});

describe("applyChange mode=revert", () => {
  test("drops the override and reverts live", async () => {
    const { dir, runtimePath } = tempPaths();
    try {
      await setOverride("toggle.test", true, runtimePath);
      const { spec, calls } = makeSpec();
      const code = await applyChange(rt, spec, {
        mode: "revert",
        runtimePath,
        systemStatePath: join(dir, "missing-system.json"),
        userPath: join(dir, "missing-user.json"),
      });
      expect(code).toBe(0);
      expect(calls.runtimeReverts).toBe(1);
      const state = await loadRuntimeState(runtimePath);
      expect(state.overrides["toggle.test"]).toBeUndefined();
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("deletes the persisted key and rebuilds when present", async () => {
    const { dir, runtimePath, statePath } = tempPaths();
    try {
      await Bun.write(
        statePath,
        JSON.stringify({ theme: { variant: "light" } }) + "\n",
      );
      const { spec } = makeSpec(persistable);
      let rebuilds = 0;
      const code = await applyChange(rt, spec, {
        mode: "revert",
        runtimePath,
        systemStatePath: statePath,
        userPath: join(dir, "missing-user.json"),
        stateWritePath: statePath,
        rebuild: async () => {
          rebuilds += 1;
          return 0;
        },
      });
      expect(code).toBe(0);
      expect(rebuilds).toBe(1);
      const persisted = await Bun.file(statePath).json();
      expect(persisted.theme).toBeUndefined();
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("skips the rebuild when nothing was persisted", async () => {
    const { dir, runtimePath, statePath } = tempPaths();
    try {
      const { spec } = makeSpec(persistable);
      let rebuilds = 0;
      const code = await applyChange(rt, spec, {
        mode: "revert",
        runtimePath,
        systemStatePath: join(dir, "missing-system.json"),
        userPath: join(dir, "missing-user.json"),
        stateWritePath: statePath,
        rebuild: async () => {
          rebuilds += 1;
          return 0;
        },
      });
      expect(code).toBe(0);
      expect(rebuilds).toBe(0);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});

import {
  BAR_SECTIONS,
  type BarOp,
  type ChangeSpec,
  type Runtime,
  applyChange,
  appendBarOp,
  barLayoutPath,
  data,
  isBarId,
  isBarSection,
  parseBarOps,
  readBarOps,
  tr,
  usageError,
  writeBarOps,
} from "@marchyo/core";
import { runThemeBarBackground, runThemeBarPosition } from "./appearance.ts";

// Runtime bar layout edits. The edits are recorded as ops in
// $XDG_STATE_HOME/marchyo/shell/bar-layout.json, which the shell applies over
// the layout shell.json (or the default) resolves, so shell.json stays
// generated and read-only. The override value is the file's JSON, which makes
// `marchyo runtime restore` rewrite an identical file.

export const barLayoutChangeBase: ChangeSpec = {
  key: "appearance.barLayout",
  runtimeApply: async (ctx) => {
    if (typeof ctx.value !== "string") throw new Error("appearance.barLayout needs the layout ops");
    const ops = parseBarOps(JSON.parse(ctx.value));
    await writeBarOps(ops);
    return JSON.stringify({ ops });
  },
  runtimeRevert: async () => {
    await writeBarOps([]);
  },
};

function record(rt: Runtime, op: BarOp): Promise<number> {
  const ops = appendBarOp(readBarOps(), op);
  return applyChange(rt, barLayoutChangeBase, {
    mode: "runtime",
    value: JSON.stringify({ ops }),
  });
}

function badId(rt: Runtime, id: string): number {
  return usageError(
    rt,
    tr("bar.invalidId", id),
    "marchyo bar put marchyo.cpu left",
  );
}

function badSection(rt: Runtime, section: string): number {
  return usageError(
    rt,
    tr("bar.invalidSection", section, BAR_SECTIONS.join("|")),
    `marchyo bar put <id> <${BAR_SECTIONS.join("|")}>`,
  );
}

export function parseAt(value: string | undefined): number | null | undefined {
  if (value === undefined) return undefined;
  if (!/^\d+$/.test(value)) return null;
  return Number(value);
}

export async function runBarList(rt: Runtime): Promise<number> {
  const ops = readBarOps();
  data(rt, { path: barLayoutPath(), ops }, () =>
    ops.length === 0 ? tr("bar.noEdits") : ops.map(describeOp).join("\n"),
  );
  return 0;
}

function describeOp(op: BarOp): string {
  switch (op.op) {
    case "put":
      return `put ${op.id} ${op.section}${op.at === undefined ? "" : ` at ${op.at}`}`;
    case "remove":
      return `remove ${op.id}`;
    case "set":
      return `set ${op.section} ${op.ids.join(" ")}`;
    case "shift":
      return `shift ${op.id} by ${op.by}`;
  }
}

export async function runBarPut(
  rt: Runtime,
  id: string,
  section: string,
  opts: { at?: string },
): Promise<number> {
  if (!isBarId(id)) return badId(rt, id);
  if (!isBarSection(section)) return badSection(rt, section);
  const at = parseAt(opts.at);
  if (at === null) return usageError(rt, tr("bar.invalidAt", opts.at ?? ""), "marchyo bar put <id> <section> --at 0");
  return record(rt, at === undefined ? { op: "put", id, section } : { op: "put", id, section, at });
}

export async function runBarRemove(rt: Runtime, id: string): Promise<number> {
  if (!isBarId(id)) return badId(rt, id);
  return record(rt, { op: "remove", id });
}

export async function runBarSet(rt: Runtime, section: string, ids: string[]): Promise<number> {
  if (!isBarSection(section)) return badSection(rt, section);
  const bad = ids.find((i) => !isBarId(i));
  if (bad !== undefined) return badId(rt, bad);
  return record(rt, { op: "set", section, ids });
}

export async function runBarMove(
  rt: Runtime,
  id: string,
  direction: string,
  count: string | undefined,
): Promise<number> {
  if (!isBarId(id)) return badId(rt, id);
  if (direction !== "left" && direction !== "right") {
    return usageError(rt, tr("bar.invalidDirection", direction), "marchyo bar move marchyo.cpu left");
  }
  const n = count === undefined ? 1 : /^\d+$/.test(count) ? Number(count) : null;
  if (n === null) {
    return usageError(rt, tr("bar.invalidShift", count ?? ""), "marchyo bar move marchyo.cpu left 2");
  }
  return record(rt, { op: "shift", id, by: direction === "left" ? -n : n });
}

export async function runBarReset(rt: Runtime): Promise<number> {
  return applyChange(rt, barLayoutChangeBase, { mode: "revert" });
}

export function runBarBackground(rt: Runtime, mode: string | undefined, opts: { revert?: boolean }): Promise<number> {
  return runThemeBarBackground(rt, mode, opts);
}

export function runBarPosition(rt: Runtime, pos: string | undefined, opts: { revert?: boolean }): Promise<number> {
  return runThemeBarPosition(rt, pos, opts);
}

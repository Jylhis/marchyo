import { expect, test } from "bun:test";
import { mkdtempSync, readFileSync, readdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  appendBarOp,
  barLayoutPath,
  parseBarOps,
  readBarOps,
  writeBarOps,
} from "../src/bar-layout.ts";

const scratch = (): string =>
  join(mkdtempSync(join(tmpdir(), "marchyo-bar-")), "shell", "bar-layout.json");

test("barLayoutPath follows XDG_STATE_HOME", () => {
  expect(barLayoutPath({ XDG_STATE_HOME: "/s" })).toBe("/s/marchyo/shell/bar-layout.json");
});

test("parseBarOps keeps well-formed ops and drops the rest", () => {
  expect(
    parseBarOps({
      ops: [
        { op: "put", id: "a", section: "centerEnd", at: 1.9 },
        { op: "put", id: "a", section: "middle" },
        { op: "remove", id: "bad id" },
        { op: "set", section: "left", ids: ["x", "y"] },
        { op: "shift", id: "z", by: -2.5 },
        "junk",
      ],
    }),
  ).toEqual([
    { op: "put", id: "a", section: "centerEnd", at: 1 },
    { op: "set", section: "left", ids: ["x", "y"] },
    { op: "shift", id: "z", by: -2 },
  ]);
  expect(parseBarOps(null)).toEqual([]);
  expect(parseBarOps({ ops: 3 })).toEqual([]);
});

test("a later put or remove of the same id replaces the earlier one", () => {
  let ops = appendBarOp([], { op: "put", id: "a", section: "left" });
  ops = appendBarOp(ops, { op: "put", id: "b", section: "left" });
  ops = appendBarOp(ops, { op: "remove", id: "a" });
  expect(ops).toEqual([
    { op: "put", id: "b", section: "left" },
    { op: "remove", id: "a" },
  ]);
});

test("separators accumulate instead of replacing each other", () => {
  let ops = appendBarOp([], { op: "put", id: "marchyo.separator", section: "left", at: 1 });
  ops = appendBarOp(ops, { op: "put", id: "marchyo.separator", section: "right" });
  expect(ops).toHaveLength(2);
});

test("writeBarOps writes atomically, reads back, and an empty list deletes the file", async () => {
  const path = scratch();
  await writeBarOps([{ op: "remove", id: "a" }], path);
  expect(readBarOps(path)).toEqual([{ op: "remove", id: "a" }]);
  expect(readdirSync(join(path, "..")).filter((f) => f.includes("tmp"))).toEqual([]);
  expect(JSON.parse(readFileSync(path, "utf8"))).toEqual({ ops: [{ op: "remove", id: "a" }] });
  await writeBarOps([], path);
  expect(readBarOps(path)).toEqual([]);
});

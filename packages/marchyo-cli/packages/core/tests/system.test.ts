import { test, expect } from "bun:test";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { mkdtempSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import {
  formatArgv,
  flakeUpdateArgv,
  sudoWrap,
  rollbackArgv,
  parseGcPeriod,
  gcArgv,
  listSystemGenerations,
  pickDiffTargets,
  type Generation,
} from "../src/system.ts";
import { rebuildArgv } from "../src/flake.ts";

// --- sudoWrap -------------------------------------------------------------

test("sudoWrap as root leaves the argv bare", () => {
  const { argv, needsSudo } = sudoWrap(["true"], {}, true);
  expect(argv).toEqual(["true"]);
  expect(needsSudo).toBe(false);
});

test("sudoWrap as user prefixes sudo (sudo -n under noInput)", () => {
  expect(sudoWrap(["true"], {}, false).argv).toEqual(["sudo", "true"]);
  expect(sudoWrap(["true"], { noInput: true }, false).argv).toEqual([
    "sudo",
    "-n",
    "true",
  ]);
});

// --- formatArgv -----------------------------------------------------------

test("formatArgv joins plain args without quoting", () => {
  expect(formatArgv(["nix", "flake", "update"])).toBe("nix flake update");
});

test("formatArgv quotes args containing whitespace", () => {
  expect(formatArgv(["dix", "/path/with space"])).toBe(
    'dix "/path/with space"',
  );
});

// --- flakeUpdateArgv ------------------------------------------------------

test("flakeUpdateArgv targets the flake path", () => {
  expect(flakeUpdateArgv("/etc/nixos")).toEqual([
    "nix",
    "flake",
    "update",
    "--flake",
    "/etc/nixos",
  ]);
});

// --- rebuildArgv (exported for upgrade dry-run) ---------------------------

test("rebuildArgv as root builds a bare nixos-rebuild switch", () => {
  // isRoot is derived from uid inside rebuildArgv; assert shape via the
  // stable tail of the argv regardless of the sudo prefix.
  const { argv } = rebuildArgv({ flakePath: "/etc/nixos" });
  expect(argv.slice(-5)).toEqual([
    "nixos-rebuild",
    "switch",
    "--impure",
    "--flake",
    "/etc/nixos",
  ]);
});

// --- rollbackArgv ---------------------------------------------------------

test("rollbackArgv as root is bare", () => {
  const { argv, needsSudo } = rollbackArgv({}, true);
  expect(argv).toEqual(["nixos-rebuild", "switch", "--rollback"]);
  expect(needsSudo).toBe(false);
});

test("rollbackArgv as user wraps in sudo", () => {
  const { argv, needsSudo } = rollbackArgv({}, false);
  expect(argv).toEqual(["sudo", "nixos-rebuild", "switch", "--rollback"]);
  expect(needsSudo).toBe(true);
});

test("rollbackArgv with noInput uses sudo -n", () => {
  const { argv } = rollbackArgv({ noInput: true }, false);
  expect(argv.slice(0, 2)).toEqual(["sudo", "-n"]);
});

// --- gc -------------------------------------------------------------------

test("parseGcPeriod accepts day periods", () => {
  expect(parseGcPeriod("14d")).toBe("14d");
  expect(parseGcPeriod("30d")).toBe("30d");
});

test("parseGcPeriod rejects other units and garbage", () => {
  expect(parseGcPeriod("14")).toBeNull();
  expect(parseGcPeriod("2w")).toBeNull();
  expect(parseGcPeriod("14 d")).toBeNull();
  expect(parseGcPeriod("")).toBeNull();
});

test("gcArgv as root is bare", () => {
  const { argv, needsSudo } = gcArgv("14d", {}, true);
  expect(argv).toEqual([
    "nix-collect-garbage",
    "--delete-older-than",
    "14d",
  ]);
  expect(needsSudo).toBe(false);
});

test("gcArgv as user wraps in sudo (system generations too)", () => {
  const { argv, needsSudo } = gcArgv("30d", { noInput: true }, false);
  expect(argv).toEqual([
    "sudo",
    "-n",
    "nix-collect-garbage",
    "--delete-older-than",
    "30d",
  ]);
  expect(needsSudo).toBe(true);
});

// --- listSystemGenerations ------------------------------------------------

test("listSystemGenerations returns [] for a missing dir", () => {
  expect(listSystemGenerations("/does/not/exist")).toEqual([]);
});

test("listSystemGenerations sorts numerically and skips other entries", () => {
  const dir = mkdtempSync(join(tmpdir(), "marchyo-gen-test-"));
  try {
    symlinkSync("/nix/store/aaa-system", join(dir, "system-2-link"));
    symlinkSync("/nix/store/bbb-system", join(dir, "system-10-link"));
    symlinkSync("/nix/store/ccc-system", join(dir, "system-1-link"));
    symlinkSync("/nix/store/ddd", join(dir, "system")); // profile head, not a gen
    writeFileSync(join(dir, "not-a-link"), "");
    const gens = listSystemGenerations(dir);
    expect(gens.map((g) => g.number)).toEqual([1, 2, 10]);
    expect(gens[2]?.target).toBe("/nix/store/bbb-system");
    expect(gens[2]?.path).toBe(join(dir, "system-10-link"));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

// --- pickDiffTargets ------------------------------------------------------

function gen(number: number, target: string): Generation {
  return { number, path: `/p/system-${number}-link`, target };
}

test("pickDiffTargets: no generations -> null", () => {
  expect(pickDiffTargets("/nix/store/x", [])).toBeNull();
});

test("pickDiffTargets: pending newer generation -> current vs newest", () => {
  const t = pickDiffTargets("/nix/store/old", [
    gen(1, "/nix/store/old"),
    gen(2, "/nix/store/new"),
  ]);
  expect(t).toEqual({
    left: "/run/current-system",
    right: "/p/system-2-link",
    reason: "current-vs-newest",
  });
});

test("pickDiffTargets: running the newest -> previous vs newest", () => {
  const t = pickDiffTargets("/nix/store/new", [
    gen(1, "/nix/store/old"),
    gen(2, "/nix/store/new"),
  ]);
  expect(t).toEqual({
    left: "/p/system-1-link",
    right: "/p/system-2-link",
    reason: "previous-vs-newest",
  });
});

test("pickDiffTargets: single generation already active -> null", () => {
  expect(pickDiffTargets("/nix/store/only", [gen(1, "/nix/store/only")])).toBeNull();
});

test("pickDiffTargets: unknown current falls back to last two generations", () => {
  const t = pickDiffTargets(null, [
    gen(1, "/nix/store/old"),
    gen(2, "/nix/store/new"),
  ]);
  expect(t?.reason).toBe("previous-vs-newest");
});

import { test, expect } from "bun:test";
import {
  hostConfigKey,
  optionsExpr,
  searchOptions,
  type OptionInfo,
} from "../src/options-eval.ts";

test("hostConfigKey maps x64 to x86_64", () => {
  expect(hostConfigKey("x64")).toBe("x86_64");
});

test("hostConfigKey maps arm64 to aarch64", () => {
  expect(hostConfigKey("arm64")).toBe("aarch64");
});

test("hostConfigKey returns null on unknown arch", () => {
  expect(hostConfigKey("s390x")).toBeNull();
  expect(hostConfigKey("riscv64")).toBeNull();
});

test("hostConfigKey defaults to the current process arch", () => {
  // On any CI/dev machine we run, process.arch is x64 or arm64.
  expect(["x86_64", "aarch64"]).toContain(hostConfigKey() ?? "");
});

test("optionsExpr embeds the flake path and preferred config", () => {
  const expr = optionsExpr("/etc/nixos", "aarch64");
  expect(expr).toContain("builtins.getFlake (toString /etc/nixos)");
  expect(expr).toContain('preferred = "aarch64";');
});

test("optionsExpr falls back to the first configuration when no name", () => {
  const expr = optionsExpr("/etc/nixos", null);
  // Empty preferred string forces the builtins.head fallback branch.
  expect(expr).toContain('preferred = "";');
  expect(expr).toContain("builtins.head names");
});

test("optionsExpr never hardcodes a configuration lookup", () => {
  const expr = optionsExpr("/etc/nixos", null);
  expect(expr).not.toContain("nixosConfigurations.x86_64");
});

test("optionsExpr warns via builtins.trace when preferred config is absent", () => {
  const expr = optionsExpr("/etc/nixos", "aarch64");
  expect(expr).toContain("builtins.trace");
  expect(expr).toContain("not found");
});

test("optionsExpr rejects flake paths unsafe to splice into Nix", () => {
  expect(() => optionsExpr("/path/with space", null)).toThrow(
    "not a plain absolute path",
  );
  expect(() => optionsExpr('relative/path', null)).toThrow();
  expect(() => optionsExpr('/tmp/"; import <nixpkgs>', null)).toThrow();
});

test("optionsExpr rejects malformed configuration names", () => {
  expect(() => optionsExpr("/etc/nixos", 'x"; evil')).toThrow(
    "invalid nixosConfiguration name",
  );
});

const OPTS: OptionInfo[] = [
  { path: "marchyo.theme.variant", description: "Theme variant" },
  { path: "marchyo.desktop.enable", description: "Enable the desktop stack" },
];

test("searchOptions matches on path substring first", () => {
  const r = searchOptions(OPTS, "theme");
  expect(r[0]?.path).toBe("marchyo.theme.variant");
});

test("searchOptions matches description text", () => {
  const r = searchOptions(OPTS, "desktop stack");
  expect(r).toHaveLength(1);
  expect(r[0]?.path).toBe("marchyo.desktop.enable");
});

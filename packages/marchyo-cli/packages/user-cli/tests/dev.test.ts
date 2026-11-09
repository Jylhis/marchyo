import { expect, test } from "bun:test";
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { buildRuntime } from "@marchyo/core";
import { addDbPreset, devLanguages, runDevDb, runDevInit } from "../src/commands/dev.ts";

const rt = () => buildRuntime({ format: "text", quiet: true });
const tmp = () => mkdtempSync(join(tmpdir(), "marchyo-dev-"));

test("init covers the omarchy language list", () => {
  for (const l of ["go", "rust", "python", "node", "bun", "ruby", "elixir", "java", "zig"]) {
    expect(devLanguages()).toContain(l);
  }
  for (const l of ["php", "dotnet", "deno", "ocaml", "clojure", "scala"]) {
    expect(devLanguages()).toContain(l);
  }
});

test("init writes devenv.nix, devenv.yaml and .envrc", async () => {
  const dir = tmp();
  expect(await runDevInit(rt(), "go", {}, dir)).toBe(0);
  expect(readFileSync(join(dir, "devenv.nix"), "utf8")).toContain("languages.go.enable");
  expect(existsSync(join(dir, "devenv.yaml"))).toBe(true);
  expect(readFileSync(join(dir, ".envrc"), "utf8")).toContain("use devenv");
});

test("init refuses to overwrite without --force", async () => {
  const dir = tmp();
  writeFileSync(join(dir, "devenv.nix"), "mine\n");
  expect(await runDevInit(rt(), "rust", {}, dir)).toBe(1);
  expect(readFileSync(join(dir, "devenv.nix"), "utf8")).toBe("mine\n");
  expect(await runDevInit(rt(), "rust", { force: true }, dir)).toBe(0);
  expect(readFileSync(join(dir, "devenv.nix"), "utf8")).toContain("languages.rust");
});

test("init rejects an unknown language with a usage error", async () => {
  expect(await runDevInit(rt(), "cobol", {}, tmp())).toBe(2);
});

test("db adds a preset once", async () => {
  const dir = tmp();
  await runDevInit(rt(), "go", {}, dir);
  expect(await runDevDb(rt(), "postgres", dir)).toBe(0);
  const once = readFileSync(join(dir, "devenv.nix"), "utf8");
  expect(once).toContain("services.postgres");
  expect(await runDevDb(rt(), "postgres", dir)).toBe(0);
  expect(readFileSync(join(dir, "devenv.nix"), "utf8")).toBe(once);
  expect(once.trimEnd().endsWith("}")).toBe(true);
});

test("db refuses a missing or oddly shaped devenv.nix", async () => {
  const dir = tmp();
  expect(await runDevDb(rt(), "redis", dir)).toBe(1);
  writeFileSync(join(dir, "devenv.nix"), "import ./other.nix\n");
  expect(await runDevDb(rt(), "redis", dir)).toBe(1);
  expect(readFileSync(join(dir, "devenv.nix"), "utf8")).toBe("import ./other.nix\n");
});

test("mariadb needs pkgs and shares the mysql slot", () => {
  const noPkgs = addDbPreset("{ ... }:\n{\n}\n", "mariadb");
  expect(noPkgs.status).toBe("refused");
  const ok = addDbPreset("{ pkgs, ... }:\n{\n}\n", "mariadb");
  expect(ok.status).toBe("added");
  expect(addDbPreset(ok.text, "mysql").status).toBe("present");
});

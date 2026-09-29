import { afterAll, beforeAll, expect, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { Runtime } from "@marchyo/core";
import {
  type PluginPrefetch,
  runPluginAdd,
  runPluginList,
  runPluginRemove,
} from "../src/commands/plugin.ts";

// Quiet, non-interactive runtime so the commands never prompt or emit noise.
const rt: Runtime = {
  format: "text",
  noColor: true,
  forceColor: false,
  plain: false,
  noAnimation: true,
  noInput: true,
  quiet: true,
  verbose: 0,
};

// A prefetch stub pointing at a temp tree with a manifest.json, so add() never
// touches the network. rev/hash are arbitrary — dry-run never fetches for real.
function stubPrefetch(treePath: string): PluginPrefetch {
  return async () => ({
    rev: "0123456789abcdef0123456789abcdef01234567",
    hash: "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
    path: treePath,
  });
}

let dir: string;
let manifestTree: string;
let emptyTree: string;

beforeAll(() => {
  dir = mkdtempSync(join(tmpdir(), "marchyo-plugin-test-"));
  manifestTree = join(dir, "with-manifest");
  emptyTree = join(dir, "no-manifest");
  Bun.write(join(manifestTree, ".keep"), "");
  Bun.write(join(emptyTree, ".keep"), "");
  // Isolate user state to the temp dir so list/remove see no ambient plugins.
  process.env.XDG_CONFIG_HOME = join(dir, "config");
});

afterAll(() => {
  rmSync(dir, { recursive: true, force: true });
});

function writeManifest(id: string): void {
  writeFileSync(
    join(manifestTree, "manifest.json"),
    JSON.stringify({
      schemaVersion: 1,
      id,
      name: "Example",
      version: "1",
      kinds: ["bar-widget"],
      entryPoints: { barWidget: "Panel.qml" },
    }),
  );
}

test("add rejects the reserved marchyo.* namespace", async () => {
  writeManifest("marchyo.evil");
  const code = await runPluginAdd(rt, "https://example.com/p.git", {
    dryRun: true,
    prefetch: stubPrefetch(manifestTree),
  });
  expect(code).toBe(1);
});

test("add rejects a source with no manifest.json", async () => {
  const code = await runPluginAdd(rt, "https://example.com/p.git", {
    dryRun: true,
    prefetch: stubPrefetch(emptyTree),
  });
  expect(code).toBe(1);
});

test("add fails cleanly when the prefetch cannot resolve the source", async () => {
  const code = await runPluginAdd(rt, "https://example.com/p.git", {
    dryRun: true,
    prefetch: async () => null,
  });
  expect(code).toBe(1);
});

test("add accepts a valid non-reserved plugin (dry run, no rebuild)", async () => {
  writeManifest("example.hello");
  const code = await runPluginAdd(rt, "https://example.com/p.git", {
    dryRun: true,
    prefetch: stubPrefetch(manifestTree),
  });
  expect(code).toBe(0);
});

test("list on empty state exits 0", async () => {
  const code = await runPluginList(rt);
  expect(code).toBe(0);
});

test("remove of an unknown plugin exits 1", async () => {
  const code = await runPluginRemove(rt, "nobody.here", { dryRun: true });
  expect(code).toBe(1);
});

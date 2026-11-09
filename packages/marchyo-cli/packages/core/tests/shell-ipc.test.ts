import { test, expect } from "bun:test";
import { mkdtempSync, mkdirSync, realpathSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  ShellIpcError,
  parseBakedToolPaths,
  parseShellIpcResult,
  shellConfigQmlPath,
  shellIpcArgv,
  shellIpcWith,
} from "../src/shell-ipc.ts";

function kindOf(fn: () => unknown): string | null {
  try {
    fn();
    return null;
  } catch (e) {
    return e instanceof ShellIpcError ? e.kind : "other";
  }
}

test("shellIpcArgv targets the shell IpcHandler through the wrapper", () => {
  expect(shellIpcArgv("togglePanel", "audio")).toEqual([
    "marchyo-shell",
    "ipc",
    "-n",
    "call",
    "--",
    "shell",
    "togglePanel",
    "audio",
  ]);
});

test("parseShellIpcResult returns the trimmed reply", () => {
  expect(parseShellIpcResult("toggleBar", { code: 0, stdout: "on\n" })).toBe("on");
});

test("parseShellIpcResult classifies the failure modes", () => {
  expect(kindOf(() => parseShellIpcResult("ping", { code: 127, stdout: "" }))).toBe(
    "not-installed",
  );
  expect(
    kindOf(() =>
      parseShellIpcResult("ping", {
        code: 255,
        stdout: 'No running instances for "/nix/store/x/shell.qml"\n',
      }),
    ),
  ).toBe("not-running");
  // quickshell exits 0 for a rejected call; only the reply says so.
  expect(
    kindOf(() => parseShellIpcResult("nope", { code: 0, stdout: "Function not found.\n" })),
  ).toBe("call-failed");
  expect(
    kindOf(() =>
      parseShellIpcResult("togglePanel", {
        code: 0,
        stdout: "Too few arguments provided (1 required but 0 were provided.)\n",
      }),
    ),
  ).toBe("call-failed");
  expect(kindOf(() => parseShellIpcResult("ping", { code: 1, stdout: "" }))).toBe(
    "call-failed",
  );
});

test("shellIpcWith passes the argv to the injected exec", async () => {
  const seen: string[][] = [];
  const reply = await shellIpcWith(
    async (argv) => {
      seen.push(argv);
      return { code: 0, stdout: "ok\n" };
    },
    "ping",
  );
  expect(reply).toBe("ok");
  expect(seen).toEqual([shellIpcArgv("ping")]);
});

test("parseBakedToolPaths keeps absolute paths and skips bare names", () => {
  const qml = `
QtObject {
  readonly property string hyprctl: "/nix/store/abc-hyprland/bin/hyprctl"
  readonly property string terminal: "ghostty"
  readonly property string curl: "/nix/store/def-curl/bin/curl"
}`;
  expect(parseBakedToolPaths(qml)).toEqual({
    hyprctl: "/nix/store/abc-hyprland/bin/hyprctl",
    curl: "/nix/store/def-curl/bin/curl",
  });
});

test("shellConfigQmlPath resolves the wrapper symlink to its package", () => {
  const dir = mkdtempSync(join(tmpdir(), "marchyo-shell-ipc-"));
  const out = join(dir, "out");
  mkdirSync(join(out, "bin"), { recursive: true });
  mkdirSync(join(out, "share", "marchyo", "shell", "Commons"), { recursive: true });
  writeFileSync(join(out, "bin", "marchyo-shell"), "");
  const qml = join(out, "share", "marchyo", "shell", "Commons", "Config.qml");
  writeFileSync(qml, "");
  mkdirSync(join(dir, "profile", "bin"), { recursive: true });
  symlinkSync(join(out, "bin", "marchyo-shell"), join(dir, "profile", "bin", "marchyo-shell"));

  expect(shellConfigQmlPath(join(dir, "profile", "bin"))).toBe(realpathSync(qml));
  expect(shellConfigQmlPath("")).toBeNull();
});

import { test, expect } from "bun:test";
import { createHash } from "node:crypto";
import { mkdtempSync, mkdirSync, realpathSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  ShellIpcError,
  encodeShellRequest,
  parseBakedToolPaths,
  parseShellIpcResult,
  parseShellReply,
  shellConfigQmlPath,
  shellIpcArgv,
  shellIpcWith,
  shellSocketCall,
  shellSocketName,
  shellSocketPath,
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

test("shellSocketName matches shell.qml's md5 of the shell dir and display", () => {
  const name = shellSocketName("/nix/store/x/share/marchyo/shell", "wayland-1");
  const id = createHash("md5").update("/nix/store/x/share/marchyo/shell\nwayland-1").digest("hex");
  expect(name).toBe(`marchyo-shell-${id.slice(0, 16)}.sock`);
});

test("shellSocketPath needs a runtime dir, a shell dir and a live socket", () => {
  const dir = mkdtempSync(join(tmpdir(), "marchyo-shell-sock-"));
  const env = { XDG_RUNTIME_DIR: dir, WAYLAND_DISPLAY: "wayland-1" };
  expect(shellSocketPath(env, "/s")).toBeNull();
  writeFileSync(join(dir, shellSocketName("/s", "wayland-1")), "");
  expect(shellSocketPath(env, "/s")).toBe(join(dir, shellSocketName("/s", "wayland-1")));
  expect(shellSocketPath({ WAYLAND_DISPLAY: "wayland-1" }, "/s")).toBeNull();
  expect(shellSocketPath(env, null)).toBeNull();
});

test("encodeShellRequest frames fields and refuses separators", () => {
  expect(encodeShellRequest("togglePanel", ["audio"])).toBe("shell\x1ftogglePanel\x1faudio\x1e");
  expect(encodeShellRequest("ping", [])).toBe("shell\x1fping\x1e");
  expect(encodeShellRequest("setBar", ["a\x1fb"])).toBeNull();
  expect(encodeShellRequest("setBar", ["a\x1eb"])).toBeNull();
});

test("parseShellReply needs the record separator before it trusts a reply", () => {
  expect(parseShellReply("OK\x1fon\n\x1e")).toEqual({ kind: "ok", output: "on" });
  expect(parseShellReply("OK\x1f\x1e")).toEqual({ kind: "ok", output: "" });
  expect(parseShellReply("SKIP\x1e")).toEqual({ kind: "skip" });
  expect(parseShellReply("ERR\x1fboom\x1e")).toEqual({ kind: "error", message: "boom" });
  expect(parseShellReply("OK\x1fon")).toEqual({ kind: "partial" });
  expect(parseShellReply("WAT\x1e").kind).toBe("error");
});

// A fake shell on a real unix socket: replies per request, or never.
function fakeShell(answer: (request: string) => string | null): {
  path: string;
  stop: () => void;
} {
  const dir = mkdtempSync(join(tmpdir(), "marchyo-shell-srv-"));
  const path = join(dir, "s.sock");
  const server = Bun.listen({
    unix: path,
    socket: {
      data(socket, chunk) {
        const reply = answer(chunk.toString());
        if (reply !== null) {
          socket.write(reply);
          socket.end();
        }
      },
    },
  });
  return { path, stop: () => server.stop(true) };
}

async function rejection(p: Promise<unknown>): Promise<string | null> {
  try {
    await p;
    return null;
  } catch (e) {
    return e instanceof ShellIpcError ? e.kind : "other";
  }
}

test("shellSocketCall returns the OK output", async () => {
  const seen: string[] = [];
  const srv = fakeShell((r) => {
    seen.push(r);
    return "OK\x1fon\x1e";
  });
  try {
    expect(await shellSocketCall(srv.path, "toggleBar", [])).toBe("on");
    expect(seen).toEqual(["shell\x1ftoggleBar\x1e"]);
  } finally {
    srv.stop();
  }
});

test("shellSocketCall yields null on SKIP and without a socket", async () => {
  const srv = fakeShell(() => "SKIP\x1e");
  try {
    expect(await shellSocketCall(srv.path, "nope", [])).toBeNull();
  } finally {
    srv.stop();
  }
  expect(await shellSocketCall("/nonexistent/marchyo.sock", "ping", [])).toBeNull();
  expect(await shellSocketCall("/nonexistent/marchyo.sock", "setBar", ["a\x1eb"])).toBeNull();
});

test("shellSocketCall reports ERR and a silent shell instead of retrying", async () => {
  const failing = fakeShell(() => "ERR\x1fboom\x1e");
  try {
    expect(await rejection(shellSocketCall(failing.path, "boom", []))).toBe("call-failed");
  } finally {
    failing.stop();
  }
  const silent = fakeShell(() => null);
  try {
    expect(await rejection(shellSocketCall(silent.path, "ping", [], 100))).toBe("call-failed");
  } finally {
    silent.stop();
  }
});

import { existsSync, readFileSync, realpathSync } from "node:fs";
import { dirname, join } from "node:path";
import { commandAvailable } from "./flake.ts";
import { captureArgv } from "./system.ts";

// The one bridge from the CLI into the running marchyo shell: the stock
// `IpcHandler { target: "shell" }` in shell/shell.qml, reached through the
// `marchyo-shell` wrapper (it bakes its own `-p <store-path>`, so the call
// self-targets the running instance). Every call site passes the function
// name as a string literal: tests/shell/contracts-test.sh greps
// `shellIpc("<fn>"` across the CLI sources and fails when shell.qml lacks it.

export const SHELL_BIN = "marchyo-shell";
export const SHELL_IPC_TARGET = "shell";

export type ShellIpcErrorKind = "not-installed" | "not-running" | "call-failed";

export class ShellIpcError extends Error {
  override name = "ShellIpcError";
  constructor(
    readonly kind: ShellIpcErrorKind,
    message: string,
  ) {
    super(message);
  }
}

export type ShellIpcExec = (
  argv: string[],
) => Promise<{ code: number; stdout: string }>;

export function shellIpcArgv(fn: string, ...args: string[]): string[] {
  return [SHELL_BIN, "ipc", "-n", "call", "--", SHELL_IPC_TARGET, fn, ...args];
}

// quickshell reports a bad call on stdout with exit 0, so the reply text is
// the only signal that the method or its arity did not match.
const CALL_ERROR =
  /^(Function not found\.|Target not found\.|Too (few|many) arguments)/;

// Classify one `marchyo-shell ipc -n call` result. Pure, for unit tests.
export function parseShellIpcResult(
  fn: string,
  r: { code: number; stdout: string },
): string {
  const out = r.stdout.trim();
  if (r.code === 127) throw notInstalled();
  if (/No running instances/.test(out)) {
    throw new ShellIpcError("not-running", "the marchyo shell is not running");
  }
  if (r.code !== 0) {
    throw new ShellIpcError(
      "call-failed",
      `shell ${fn} failed (exit ${r.code})${out ? `: ${out}` : ""}`,
    );
  }
  if (CALL_ERROR.test(out)) {
    throw new ShellIpcError(
      "call-failed",
      `shell ${fn}: ${out.split("\n")[0]}`,
    );
  }
  return out;
}

// Call `fn` on the running shell and return its reply. Throws ShellIpcError
// when the wrapper is absent, the shell is not running, or the call is
// rejected.
export async function shellIpcWith(
  exec: ShellIpcExec,
  fn: string,
  ...args: string[]
): Promise<string> {
  return parseShellIpcResult(fn, await exec(shellIpcArgv(fn, ...args)));
}

export function shellIpc(fn: string, ...args: string[]): Promise<string> {
  if (!commandAvailable(SHELL_BIN)) {
    return Promise.reject(notInstalled());
  }
  return shellIpcWith(captureArgv, fn, ...args);
}

function notInstalled(): ShellIpcError {
  return new ShellIpcError(
    "not-installed",
    `${SHELL_BIN} not found in PATH (marchyo.shell.enable = false?)`,
  );
}

export function shellInstalled(): boolean {
  return commandAvailable(SHELL_BIN);
}

// The store shell's generated Commons/Config.qml, found next to the resolved
// wrapper ($out/bin/marchyo-shell -> $out/share/marchyo/shell). Null when the
// wrapper is not on PATH or the file is absent.
export function shellConfigQmlPath(
  path: string = process.env.PATH ?? "",
): string | null {
  for (const dir of path.split(":")) {
    if (dir === "") continue;
    const candidate = join(dir, SHELL_BIN);
    if (!existsSync(candidate)) continue;
    try {
      const out = dirname(dirname(realpathSync(candidate)));
      const qml = join(out, "share", "marchyo", "shell", "Commons", "Config.qml");
      return existsSync(qml) ? qml : null;
    } catch {
      return null;
    }
  }
  return null;
}

// The absolute tool paths a generated Config.qml bakes, by property name.
// Bare names (the checked-in dev defaults) are skipped: they resolve on PATH.
export function parseBakedToolPaths(qml: string): Record<string, string> {
  const tools: Record<string, string> = {};
  const re = /readonly property string (\w+):\s*"(\/[^"]*)"/g;
  for (const m of qml.matchAll(re)) {
    if (m[1] !== undefined && m[2] !== undefined) tools[m[1]] = m[2];
  }
  return tools;
}

export function readBakedToolPaths(qmlPath: string): Record<string, string> {
  return parseBakedToolPaths(readFileSync(qmlPath, "utf8"));
}

import { existsSync, readFileSync, realpathSync } from "node:fs";
import { dirname, join } from "node:path";
import { commandAvailable } from "./flake.ts";
import { captureArgv } from "./system.ts";

// The one bridge from the CLI into the running marchyo shell's function table
// (`actions` in shell/shell.qml). The shell's unix socket answers first; the
// `IpcHandler { target: "shell" }`, reached through the `marchyo-shell`
// wrapper (it bakes its own `-p <store-path>`, so the call self-targets the
// running instance), answers when the socket is absent or skips the call.
// Every call site passes the function name as a string literal:
// tests/shell/contracts-test.sh greps `shellIpc("<fn>"` across the CLI sources
// and fails when shell.qml lacks it.

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

export async function shellIpc(fn: string, ...args: string[]): Promise<string> {
  if (!commandAvailable(SHELL_BIN)) throw notInstalled();
  const socket = shellSocketPath();
  if (socket !== null) {
    const reply = await shellSocketCall(socket, fn, args);
    if (reply !== null) return reply;
  }
  return shellIpcWith(captureArgv, fn, ...args);
}

// The shell's own unix socket (shell.qml SocketServer, framed like
// shell/Commons/ShellSocket.js): a Bun socket connects in a few ms where a
// `qs ipc` client takes tens. Fields are split by the unit separator and the
// request ends with the record separator.
export const UNIT = "\x1f";
export const RECORD = "\x1e";
export const SOCKET_TIMEOUT_MS = 2000;

// marchyo-shell-<16 hex of md5(shell dir "\n" WAYLAND_DISPLAY)>.sock, the name
// shell.qml derives from Quickshell.shellDir and its own WAYLAND_DISPLAY.
export function shellSocketName(shellDir: string, waylandDisplay: string): string {
  const id = new Bun.CryptoHasher("md5").update(`${shellDir}\n${waylandDisplay}`).digest("hex");
  return `marchyo-shell-${id.slice(0, 16)}.sock`;
}

export function shellSocketPath(
  env: NodeJS.ProcessEnv = process.env,
  shellDir: string | null = shellShareDir(env.PATH ?? ""),
): string | null {
  const runtime = env.XDG_RUNTIME_DIR;
  if (!runtime || shellDir === null) return null;
  const path = join(runtime, shellSocketName(shellDir, env.WAYLAND_DISPLAY ?? ""));
  return existsSync(path) ? path : null;
}

// Null when an argument cannot be framed (it holds a separator).
export function encodeShellRequest(fn: string, args: string[]): string | null {
  const fields = [SHELL_IPC_TARGET, fn, ...args];
  if (fields.some((f) => f.includes(UNIT) || f.includes(RECORD))) return null;
  return fields.join(UNIT) + RECORD;
}

export type ShellSocketReply =
  | { kind: "ok"; output: string }
  | { kind: "skip" }
  | { kind: "error"; message: string }
  | { kind: "partial" };

// Classify the bytes read so far. A reply counts only once its record
// separator arrived, so a cut-off answer never passes for the whole of it.
export function parseShellReply(raw: string): ShellSocketReply {
  const end = raw.indexOf(RECORD);
  if (end < 0) return { kind: "partial" };
  const body = raw.slice(0, end);
  if (body === "SKIP") return { kind: "skip" };
  if (body.startsWith(`OK${UNIT}`)) {
    return { kind: "ok", output: body.slice(3).trim() };
  }
  if (body.startsWith(`ERR${UNIT}`)) return { kind: "error", message: body.slice(4) };
  return { kind: "error", message: `unexpected reply: ${JSON.stringify(body.slice(0, 80))}` };
}

// The reply, or null when the socket ran nothing (SKIP, no connection) and
// `qs ipc` should answer instead. Once the request is out, a timeout or a
// broken reply throws: the call may already have run, so it is not retried.
export function shellSocketCall(
  path: string,
  fn: string,
  args: string[],
  timeoutMs: number = SOCKET_TIMEOUT_MS,
): Promise<string | null> {
  const request = encodeShellRequest(fn, args);
  if (request === null) return Promise.resolve(null);
  return new Promise((resolve, reject) => {
    let raw = "";
    let sent = false;
    let done = false;
    const finish = (value: string | null, error?: ShellIpcError) => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      if (error) reject(error);
      else resolve(value);
    };
    const failed = (why: string) =>
      sent
        ? finish(null, new ShellIpcError("call-failed", `shell ${fn}: ${why}`))
        : finish(null);
    const timer = setTimeout(() => failed("the shell is not responding"), timeoutMs);
    const settle = () => {
      const reply = parseShellReply(raw);
      if (reply.kind === "partial") return false;
      if (reply.kind === "ok") finish(reply.output);
      else if (reply.kind === "skip") finish(null);
      else finish(null, new ShellIpcError("call-failed", `shell ${fn}: ${reply.message}`));
      return true;
    };
    Bun.connect({
      unix: path,
      socket: {
        open(socket) {
          sent = true;
          socket.write(request);
        },
        data(socket, chunk) {
          raw += chunk.toString();
          if (settle()) socket.end();
        },
        close() {
          if (!settle()) failed("connection closed before the reply");
        },
        error(_socket, e) {
          failed(e.message);
        },
        connectError(_socket, _e) {
          finish(null);
        },
      },
    }).catch(() => finish(null));
  });
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

// The store shell's share/marchyo/shell directory, found next to the resolved
// wrapper ($out/bin/marchyo-shell -> $out/share/marchyo/shell). Null when the
// wrapper is not on PATH.
export function shellShareDir(path: string = process.env.PATH ?? ""): string | null {
  for (const dir of path.split(":")) {
    if (dir === "") continue;
    const candidate = join(dir, SHELL_BIN);
    if (!existsSync(candidate)) continue;
    try {
      return join(dirname(dirname(realpathSync(candidate))), "share", "marchyo", "shell");
    } catch {
      return null;
    }
  }
  return null;
}

// The store shell's generated Commons/Config.qml. Null when the wrapper is
// not on PATH or the file is absent.
export function shellConfigQmlPath(
  path: string = process.env.PATH ?? "",
): string | null {
  const share = shellShareDir(path);
  if (share === null) return null;
  const qml = join(share, "Commons", "Config.qml");
  return existsSync(qml) ? qml : null;
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

import {
  closeSync,
  constants,
  lstatSync,
  mkdirSync,
  openSync,
  readdirSync,
  unlinkSync,
  writeSync,
} from "node:fs";
import { randomBytes } from "node:crypto";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { captureArgv } from "./system.ts";

// Desktop notifications over org.freedesktop.Notifications, ported from
// omarchy's omarchy-notification-send. The call goes through busctl with
// every value as one typed D-Bus parameter (never notify-send, whose own
// option parsing reinterprets a relayed headline such as `--hint=x`). The
// click command rides as the `marchyo-exec-argv` / `marchyo-actions` hints.
// The shell honours them, and `marchyo-glyph`, only when `marchyo-token` is a
// one-time nonce this CLI wrote under $XDG_RUNTIME_DIR/marchyo/notify-nonce.

export const NOTIFY_DEFAULT_APP = "marchyo-action";
export const MAX_NOTIFY_ACTIONS = 3;

export type NotifyUrgency = "low" | "normal" | "critical";

export type NotifyAction = { label: string; argv: string[] };

export type NotifyRequest = {
  appName: string;
  glyph: string;
  urgency: NotifyUrgency;
  icon: string;
  image: string;
  expire: number;
  replaceId: number;
  printId: boolean;
  transient: boolean;
  headline: string;
  description: string;
  exec: string[] | null;
  actions: NotifyAction[];
};

export class NotifyUsageError extends Error {
  constructor(
    readonly lines: string[],
    readonly showUsage = false,
  ) {
    super(lines[0] ?? "invalid notification");
  }
}

export const NOTIFY_USAGE =
  "marchyo notify [--app-name <app-name>] [-g <glyph>] [-u <low|normal|critical>] " +
  "[-i <icon>] [-t <ms>] [-r <id>] [-p] [--transient] [--image <path-or-uri>] " +
  "<headline> [description] " +
  "[--exec <program> [args...] | --action <label> <program> [words...]... [--with <args...>]]";

const VALUE_FLAGS = new Set([
  "-g", "--glyph", "-u", "--urgency", "--app-name", "-i", "--icon",
  "--image", "-r", "--replace-id", "-t", "--expire-time",
]);
const VALUE_LONG_FLAGS = new Set([
  "--glyph", "--urgency", "--app-name", "--icon", "--expire-time", "--image", "--replace-id",
]);
const BARE_FLAGS = new Set(["-p", "--print-id", "--transient", "--exec", "--action"]);

// Flags that cannot be the description: a body such as "-50% off" is text.
function knownFlag(arg: string): boolean {
  if (VALUE_FLAGS.has(arg) || BARE_FLAGS.has(arg)) return true;
  const eq = arg.indexOf("=");
  return eq > 2 && arg.startsWith("--") && VALUE_LONG_FLAGS.has(arg.slice(0, eq));
}

const SPACE = /[ \t\n\r\f\v]/;

type Options = Omit<NotifyRequest, "headline" | "description" | "exec" | "actions">;

function defaults(): Options {
  return {
    appName: NOTIFY_DEFAULT_APP,
    glyph: "",
    urgency: "low",
    icon: "",
    image: "",
    expire: -1,
    replaceId: 0,
    printId: false,
    transient: false,
  };
}

function applyValue(o: Options, opt: string, val: string): void {
  switch (opt) {
    case "-g":
    case "--glyph":
      o.glyph = val;
      return;
    case "-u":
    case "--urgency":
      o.urgency = val as NotifyUrgency;
      return;
    case "--app-name":
      o.appName = val;
      return;
    case "-i":
    case "--icon":
      o.icon = val;
      return;
    case "--image":
      o.image = val;
      return;
    case "-r":
    case "--replace-id":
      if (!/^[0-9]+$/.test(val)) {
        throw new NotifyUsageError([`Invalid ${opt} value (numeric id expected): ${val}`]);
      }
      o.replaceId = Number(val);
      return;
    default:
      if (!/^-?[0-9]+$/.test(val)) {
        throw new NotifyUsageError([`Invalid ${opt} value (milliseconds expected): ${val}`]);
      }
      o.expire = Number(val);
  }
}

// A known option at args[i], in `--flag value` or `--flag=value` form.
// Returns how many args it consumed, or 0 when args[i] is not an option.
function parseOption(o: Options, args: string[], i: number): number {
  const first = args[i]!;
  if (first === "-p" || first === "--print-id") {
    o.printId = true;
    return 1;
  }
  if (first === "--transient") {
    o.transient = true;
    return 1;
  }
  const inline = first.startsWith("--") && first.indexOf("=") > 2;
  const opt = inline ? first.slice(0, first.indexOf("=")) : first;
  if (!VALUE_FLAGS.has(opt)) return 0;
  if (!inline && i + 1 >= args.length) {
    throw new NotifyUsageError([`Missing value for ${opt}`]);
  }
  applyValue(o, opt, inline ? first.slice(first.indexOf("=") + 1) : args[i + 1]!);
  return inline ? 1 : 2;
}

function parseAction(args: string[], i: number): { action: NotifyAction; next: number } {
  const rest = args.slice(i + 1);
  const label = rest[0];
  const program = rest[1];
  if (rest.length < 2 || !label || !program) {
    throw new NotifyUsageError([
      "--action needs a label and a command: --action <label> <program> [words...]",
    ]);
  }
  let end = 1;
  while (end < rest.length && !["--action", "--with", "--exec"].includes(rest[end]!)) end++;
  const words = rest.slice(1, end);
  if (words.length === 0) {
    throw new NotifyUsageError([
      "--action needs a label and a command: --action <label> <program> [words...]",
    ]);
  }
  if (words.length === 1 && SPACE.test(words[0]!)) {
    throw new NotifyUsageError([
      "--action takes the command as separate words, not one quoted string.",
      `Write:  --action "${label}" ${words[0]}`,
    ]);
  }
  return { action: { label, argv: words }, next: i + 1 + end };
}

function checkExec(exec: string[]): void {
  if (exec.length === 0 || exec[0] === "") {
    throw new NotifyUsageError(["--exec needs a command: --exec <program> [args...]"]);
  }
  if (exec.length === 1 && SPACE.test(exec[0]!)) {
    throw new NotifyUsageError([
      "--exec takes the command as separate words, not one quoted string.",
      `Write:  --exec ${exec[0]}`,
    ]);
  }
}

// The limits the shell enforces (Commons/notify/Security.js): a command that
// breaks them would arrive as a card with no command, so refuse it here.
export const MAX_ARGV_WORDS = 32;
export const MAX_ARGV_WORD_CHARS = 4096;
export const MAX_HINT_CHARS = 32768;

function checkLimits(flag: string, words: string[]): void {
  if (words[0]!.startsWith("-")) {
    throw new NotifyUsageError([`${flag} needs a program, not an option: ${words[0]}`]);
  }
  if (words.length > MAX_ARGV_WORDS) {
    throw new NotifyUsageError([`${flag} takes at most ${MAX_ARGV_WORDS} words.`]);
  }
  if (words.some((w) => w.length > MAX_ARGV_WORD_CHARS)) {
    throw new NotifyUsageError([`${flag} words can have at most ${MAX_ARGV_WORD_CHARS} characters.`]);
  }
  if (words.some((w) => w.includes("\0"))) {
    throw new NotifyUsageError([`${flag} words cannot contain a NUL character.`]);
  }
}

function checkClick(exec: string[] | null, actions: NotifyAction[]): void {
  if (exec !== null) {
    checkLimits("--exec", exec);
    if (JSON.stringify(exec).length > MAX_HINT_CHARS) {
      throw new NotifyUsageError(["--exec is too long."]);
    }
  }
  for (const a of actions) {
    if (a.label.trim() === "") {
      throw new NotifyUsageError(["--action needs a label that is not blank."]);
    }
    checkLimits("--action", a.argv);
  }
  if (actions.length > 0 && JSON.stringify(actions).length > MAX_HINT_CHARS) {
    throw new NotifyUsageError(["The --action commands are too long."]);
  }
}

// Parses the argv after `notify`. Throws NotifyUsageError for anything
// omarchy-notification-send rejects.
export function parseNotifyArgs(args: string[]): NotifyRequest {
  const o = defaults();
  let i = 0;
  for (;;) {
    const used = i < args.length ? parseOption(o, args, i) : 0;
    if (used === 0) break;
    i += used;
  }
  if (i >= args.length) throw new NotifyUsageError([], true);
  const headline = args[i++]!;
  // The description is the next positional even when it begins with a dash.
  let description = "";
  if (i < args.length && !knownFlag(args[i]!)) description = args[i++]!;

  let exec: string[] | null = null;
  let withArgs: string[] = [];
  const actions: NotifyAction[] = [];
  while (i < args.length) {
    const arg = args[i]!;
    if (arg === "--exec") {
      exec = args.slice(i + 1);
      break;
    }
    if (arg === "--action") {
      const parsed = parseAction(args, i);
      actions.push(parsed.action);
      i = parsed.next;
      continue;
    }
    if (arg === "--with") {
      withArgs = args.slice(i + 1);
      break;
    }
    const used = parseOption(o, args, i);
    if (used === 0) throw new NotifyUsageError([`Unknown option: ${arg}`], true);
    i += used;
  }

  if (!["low", "normal", "critical"].includes(o.urgency)) {
    throw new NotifyUsageError([`Unknown urgency: ${o.urgency} (use low, normal, or critical)`]);
  }
  if (exec !== null) {
    checkExec(exec);
    checkClick(exec, []);
  }
  if (actions.length > 0) {
    if (exec !== null) {
      throw new NotifyUsageError([
        "--exec and --action cannot be combined: the card click runs the first action.",
      ]);
    }
    if (actions.length > MAX_NOTIFY_ACTIONS) {
      throw new NotifyUsageError([`A notification takes at most ${MAX_NOTIFY_ACTIONS} actions.`]);
    }
    for (const a of actions) a.argv = [...a.argv, ...withArgs];
    checkClick(null, actions);
  } else if (withArgs.length > 0) {
    throw new NotifyUsageError([
      "--with gives arguments to --action; it needs at least one --action before it.",
    ]);
  }
  return { ...o, headline, description, exec, actions };
}

// A glyph counts too: without proof, any application could draw the icon
// slot of a first-party card.
export function needsToken(req: NotifyRequest): boolean {
  return req.exec !== null || req.actions.length > 0 || req.glyph !== "";
}

const URGENCY_BYTE: Record<NotifyUrgency, string> = { low: "0", normal: "1", critical: "2" };

// a{sv} hints as busctl triples (key, variant type, value).
export function notifyHints(req: NotifyRequest, token: string | null): string[] {
  const hints = ["urgency", "y", URGENCY_BYTE[req.urgency]];
  if (req.glyph !== "") hints.push("marchyo-glyph", "s", req.glyph);
  if (req.image !== "") hints.push("image-path", "s", req.image);
  if (req.transient) hints.push("transient", "b", "true");
  if (req.exec !== null) hints.push("marchyo-exec-argv", "s", JSON.stringify(req.exec));
  if (req.actions.length > 0) {
    hints.push("marchyo-actions", "s", JSON.stringify(req.actions));
    hints.push("marchyo-exec-argv", "s", JSON.stringify(req.actions[0]!.argv));
  }
  if (needsToken(req)) {
    if (token === null) throw new Error("a click command or glyph needs a trust token");
    hints.push("marchyo-token", "s", token);
  }
  return hints;
}

// Signature susssasa{sv}i: app_name, replaces_id, app_icon, summary, body,
// actions (empty), hints, expire_timeout. The leading `--` keeps a
// dash-leading value positional instead of a busctl option.
export function busctlNotifyArgv(req: NotifyRequest, token: string | null): string[] {
  const hints = notifyHints(req, token);
  return [
    "busctl", "--user", "--", "call",
    "org.freedesktop.Notifications", "/org/freedesktop/Notifications",
    "org.freedesktop.Notifications", "Notify", "susssasa{sv}i",
    req.appName, String(req.replaceId), req.icon, req.headline, req.description,
    "0",
    String(hints.length / 3), ...hints,
    String(req.expire),
  ];
}

export function notifyNonceDir(env: NodeJS.ProcessEnv = process.env): string | null {
  const runtime = env.XDG_RUNTIME_DIR;
  return runtime === undefined || runtime === "" ? null : join(runtime, "marchyo", "notify-nonce");
}

const NONCE_RE = /^[0-9a-f]{64}$/;
// A nonce the shell never spent (no shell running) is dropped after this long.
const NONCE_TTL_MS = 120_000;

function ensureDir(path: string, strict: boolean): void {
  try {
    mkdirSync(path, { recursive: true, mode: 0o700 });
  } catch (e) {
    if ((e as NodeJS.ErrnoException).code !== "EEXIST") throw e;
  }
  const st = lstatSync(path);
  const uid = process.getuid?.();
  // The leaf holds the nonces: private to this user. The parent is shared with
  // other Marchyo runtime files, so it only must not be open to writes.
  const loose = strict ? (st.mode & 0o077) !== 0 : (st.mode & 0o022) !== 0;
  if (!st.isDirectory() || (uid !== undefined && st.uid !== uid) || loose) {
    throw new Error(`unsafe notification directory (owner or mode): ${path}`);
  }
}

function pruneNonces(dir: string, now: number): void {
  for (const name of readdirSync(dir)) {
    if (!NONCE_RE.test(name)) continue;
    try {
      const file = join(dir, name);
      if (now - lstatSync(file).mtimeMs > NONCE_TTL_MS) unlinkSync(file);
    } catch {
      // Gone already, or not ours to remove.
    }
  }
}

// A fresh one-time token for one click-command notification. It is a random
// 256-bit name for an empty-looking private file; the shell spends it by
// remembering the name and removing the file, so neither a copy seen on the
// session bus nor one read from busctl's argv can be replayed. Concurrent
// senders each get their own file.
export function issueNonce(env: NodeJS.ProcessEnv = process.env, now = Date.now()): string {
  const dir = notifyNonceDir(env);
  if (dir === null) throw new Error("XDG_RUNTIME_DIR is not set; cannot attach a click command");
  ensureDir(dirname(dir), false);
  ensureDir(dir, true);
  pruneNonces(dir, now);
  const nonce = randomBytes(32).toString("hex");
  const fd = openSync(
    join(dir, nonce),
    constants.O_WRONLY | constants.O_CREAT | constants.O_EXCL | constants.O_NOFOLLOW,
    0o600,
  );
  try {
    writeSync(fd, nonce);
  } finally {
    closeSync(fd);
  }
  return nonce;
}

export type NotifyDeps = {
  env: NodeJS.ProcessEnv;
  run: (argv: string[]) => Promise<{ code: number; stdout: string }>;
};

export function defaultNotifyDeps(): NotifyDeps {
  return { env: process.env, run: captureArgv };
}

export type NotifyResult = { ok: boolean; id: number | null; error?: string };

// Sends one notification. Never throws: a missing bus or token is a result.
export async function sendNotification(
  req: NotifyRequest,
  deps: NotifyDeps = defaultNotifyDeps(),
): Promise<NotifyResult> {
  let argv: string[];
  try {
    argv = busctlNotifyArgv(req, needsToken(req) ? issueNonce(deps.env) : null);
  } catch (e) {
    return { ok: false, id: null, error: (e as Error).message };
  }
  const out = await deps.run(argv);
  if (out.code !== 0) {
    return { ok: false, id: null, error: `busctl exited with status ${out.code}` };
  }
  const id = Number(out.stdout.trim().split(/\s+/).pop());
  return { ok: true, id: Number.isInteger(id) ? id : null };
}

// A card with a headline, an optional body and one "open this panel" button,
// the shape every Marchyo first-party prompt uses.
export function actionRequest(
  headline: string,
  description: string,
  glyph: string,
  label: string,
  argv: string[],
): NotifyRequest {
  return {
    ...defaults(),
    glyph,
    headline,
    description,
    exec: null,
    actions: [{ label, argv }],
  };
}

export type NotifierWait = {
  timeoutMs: number;
  intervalMs: number;
  check: () => Promise<boolean>;
  sleep: (ms: number) => Promise<void>;
};

export function defaultNotifierWait(): NotifierWait {
  return {
    timeoutMs: 30_000,
    intervalMs: 1_000,
    check: async () =>
      (await captureArgv(["busctl", "--user", "status", "org.freedesktop.Notifications"])).code === 0,
    sleep: (ms) => Bun.sleep(ms),
  };
}

// Polls until a notification service owns its bus name; false on timeout.
export async function waitForNotifier(wait: NotifierWait = defaultNotifierWait()): Promise<boolean> {
  let waited = 0;
  for (;;) {
    if (await wait.check()) return true;
    if (waited >= wait.timeoutMs) return false;
    await wait.sleep(wait.intervalMs);
    waited += wait.intervalMs;
  }
}

export function marchyoStateDir(env: NodeJS.ProcessEnv = process.env): string {
  const base = env.XDG_STATE_HOME;
  return join(base !== undefined && base !== "" ? base : join(homedir(), ".local", "state"), "marchyo");
}

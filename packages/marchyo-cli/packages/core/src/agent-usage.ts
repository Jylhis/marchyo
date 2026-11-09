import { Database } from "bun:sqlite";
import { randomBytes } from "node:crypto";
import {
  chmodSync,
  closeSync,
  constants,
  existsSync,
  fstatSync,
  lstatSync,
  mkdirSync,
  openSync,
  readdirSync,
  readSync,
  renameSync,
  statSync,
  unlinkSync,
  writeSync,
} from "node:fs";
import { homedir } from "node:os";
import { basename, join } from "node:path";
import {
  ACCOUNT_PROVIDERS,
  type Account,
  type AccountProvider,
  type ProviderAccounts,
  type SwitchOffer,
  PROVIDER_SPECS,
  activeAccount,
  applyAutoswitch,
  hasRegistry,
  loadRegistry,
  summarizeRegistry,
} from "./agent-accounts.ts";
import { zstdDecompressSync } from "node:zlib";
import { z } from "zod";

// Usage limits and token statistics for the AI coding agents signed in on this
// machine. Credentials are read here at runtime only: a token goes into one
// request header for its provider's https host and nowhere else (not argv, not
// the cache, not an error message).

export const USAGE_SCHEMA_VERSION = 1;
export const PROBE_MIN_INTERVAL_MS = 15_000;
export const SCAN_REUSE_MS = 20_000;
const SCAN_WINDOW_DAYS = 30;
const DAY_MS = 86_400_000;
const HTTP_TIMEOUT_MS = 10_000;
const RPC_TIMEOUT_MS = 10_000;
const MAX_BODY_BYTES = 2_000_000;
const MAX_RPC_LINE_CHARS = 1_000_000;
const RPC_KILL_GRACE_MS = 1_000;
// Transcript caps: bytes read (or decompressed) per file, chars per JSONL line,
// files per scan, and bytes of state JSON read back.
export const MAX_TRANSCRIPT_BYTES = 256 * 1024 * 1024;
export const MAX_LINE_CHARS = 4 * 1024 * 1024;
export const MAX_SCAN_FILES = 20_000;
const MAX_STATE_BYTES = 64 * 1024 * 1024;
const READ_CHUNK = 1024 * 1024;

export const ENDPOINTS = {
  claude: "https://api.anthropic.com/api/oauth/usage",
  copilot: "https://api.github.com/copilot_internal/user",
  zai: "https://api.z.ai/api/monitor/usage/quota/limit",
  openrouter: "https://openrouter.ai/api/v1/key",
} as const;

export const AGENT_IDS = ["claude", "codex", "copilot", "opencode", "zai", "openrouter"] as const;
export type AgentId = (typeof AGENT_IDS)[number];
type ProbedId = Exclude<AgentId, "opencode">;
type ScannedId = "claude" | "codex" | "opencode";
type AccountedId = "claude" | "codex";

const AGENT_NAMES: Record<AgentId, string> = {
  claude: "Claude Code",
  codex: "Codex",
  copilot: "GitHub Copilot",
  opencode: "opencode",
  zai: "Z.ai",
  openrouter: "OpenRouter",
};

export interface UsageLimit {
  label: string;
  percent: number;
  resetsAt: string;
}

export interface TokenTotals {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
  total: number;
}

export interface AgentUsage {
  id: AgentId;
  name: string;
  ready: boolean;
  limits: UsageLimit[];
  limitsFetchedAt: number;
  tokens?: { today: TokenTotals; last30Days: TokenTotals };
  cost?: { currency: "USD"; today: number; last30Days: number };
  error?: string;
}

export interface ProbeResult {
  at: number;
  ready: boolean;
  limits: UsageLimit[];
  fetchedAt: number;
  error?: string;
}

type DayTotals = TokenTotals & { cost: number };
type Days = Record<string, DayTotals>;

export interface AccountUsage {
  id: string;
  label: string;
  email: string;
  plan: string;
  primary: boolean;
  active: boolean;
  signedIn: boolean;
  limits: UsageLimit[];
  limitsFetchedAt: number;
  error?: string;
}

// One provider's accounts for the panel: who is active, how switching
// happens, and each account's own limits. No home paths, no credentials.
export interface ProviderAccountsUsage extends Omit<ProviderAccounts, "accounts"> {
  accounts: AccountUsage[];
  offer?: SwitchOffer;
}

export interface UsageFile {
  schemaVersion: number;
  updatedAt: string;
  agents: AgentUsage[];
  accounts: ProviderAccountsUsage[];
  scannedAt: number;
  // Keyed by agent id for the primary sign-in, `<agent>:<home>` for an added one.
  probes: Record<string, ProbeResult>;
  scans: Partial<Record<ScannedId, Days>>;
  // Set when the state dir is unsafe or unwritable; nothing was cached.
  stateError?: string;
}

export interface UsageDeps {
  env: Record<string, string | undefined>;
  home: string;
  now: () => number;
  fetch: (url: URL, init: RequestInit) => Promise<Response>;
  ghToken: () => Promise<string>;
  notify: (title: string, body: string) => void;
}

export function defaultUsageDeps(): UsageDeps {
  const env = process.env;
  return {
    env,
    home: homedir(),
    now: () => Date.now(),
    fetch: (url, init) => fetch(url, init),
    ghToken: () => ghAuthToken(env),
    notify: notifySend,
  };
}

function notifySend(title: string, body: string): void {
  try {
    Bun.spawn(["notify-send", "-a", "marchyo", title, body], {
      stdin: "ignore",
      stdout: "ignore",
      stderr: "ignore",
    }).unref();
  } catch {
    // no notify-send here
  }
}

// ── paths ───────────────────────────────────────────────────────────────────

function xdg(env: UsageDeps["env"], home: string, key: string, fallback: string): string {
  const v = env[key];
  return v && v !== "" ? v : join(home, fallback);
}

export function usageDir(env: UsageDeps["env"] = process.env, home = homedir()): string {
  return join(xdg(env, home, "XDG_STATE_HOME", ".local/state"), "marchyo", "agents");
}

export function usagePath(env: UsageDeps["env"] = process.env, home = homedir()): string {
  return join(usageDir(env, home), "usage.json");
}

function claudeDir(d: UsageDeps): string {
  return d.env.CLAUDE_CONFIG_DIR || join(d.home, ".claude");
}

function codexHome(d: UsageDeps): string {
  return d.env.CODEX_HOME || join(d.home, ".codex");
}

function copilotHome(d: UsageDeps): string {
  return d.env.COPILOT_HOME || join(d.home, ".copilot");
}

function opencodeDb(d: UsageDeps): string {
  return d.env.OPENCODE_DB || join(xdg(d.env, d.home, "XDG_DATA_HOME", ".local/share"), "opencode", "opencode.db");
}

export function findOnPath(name: string, path: string | undefined): string | null {
  for (const dir of (path ?? "").split(":")) {
    if (dir === "") continue;
    const candidate = join(dir, name);
    try {
      const st = statSync(candidate);
      if (st.isFile() && (st.mode & 0o111) !== 0) return candidate;
    } catch {
      // not here
    }
  }
  return null;
}

// ── untrusted values ────────────────────────────────────────────────────────

function count(value: unknown): number {
  const n = typeof value === "number" ? value : typeof value === "string" ? Number(value) : NaN;
  return Number.isFinite(n) && n >= 0 && n < 1e13 ? n : 0;
}

function obj(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

// The whole file, or null when it is missing, unreadable or larger than `max`.
function readFileCapped(path: string, max: number, flags = constants.O_RDONLY): Buffer | null {
  let fd: number;
  try {
    fd = openSync(path, flags);
  } catch {
    return null;
  }
  try {
    const st = fstatSync(fd);
    if (!st.isFile() || st.size > max) return null;
    const buf = Buffer.allocUnsafe(st.size);
    let off = 0;
    while (off < st.size) {
      const n = readSync(fd, buf, off, st.size - off, off);
      if (n === 0) break;
      off += n;
    }
    return buf.subarray(0, off);
  } catch {
    return null;
  } finally {
    closeSync(fd);
  }
}

function readJson(path: string, max = 1024 * 1024, flags = constants.O_RDONLY): unknown {
  const raw = readFileCapped(path, max, flags);
  if (raw === null) return null;
  try {
    return JSON.parse(raw.toString("utf8"));
  } catch {
    return null;
  }
}

// Reads a stream to its end, failing once it passes `max` bytes.
export async function readStreamCapped(
  stream: ReadableStream<Uint8Array> | null,
  max: number,
): Promise<string | null> {
  if (stream === null) return "";
  const reader = stream.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > max) {
      await reader.cancel().catch(() => {});
      return null;
    }
    chunks.push(value);
  }
  return Buffer.concat(chunks).toString("utf8");
}

function clamp01(n: number): number {
  return Math.max(0, Math.min(1, n));
}

export function localDay(ms: number): string {
  const d = new Date(ms);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function isoTime(value: unknown, unit: "s" | "auto"): string {
  if (value === null || value === undefined || value === "") return "";
  if (typeof value === "number" || /^\d+$/.test(String(value))) {
    let n = Number(value);
    if (!Number.isFinite(n) || n <= 0) return "";
    if (unit === "s" || n < 1e12) n *= 1000;
    return new Date(n).toISOString();
  }
  const t = Date.parse(String(value));
  return Number.isNaN(t) ? "" : new Date(t).toISOString();
}

// ── HTTP ────────────────────────────────────────────────────────────────────

export class ProbeError extends Error {}

const PROVIDER_HOSTS: ReadonlySet<string> = new Set(
  Object.values(ENDPOINTS).map((e) => new URL(e).hostname),
);

export function assertEndpoint(url: URL): void {
  const ok =
    url.protocol === "https:" &&
    PROVIDER_HOSTS.has(url.hostname) &&
    url.port === "" &&
    url.username === "" &&
    url.password === "";
  if (!ok) throw new ProbeError(`refused to send a credential to ${url.protocol}//${url.host}`);
}

// Error messages are built from the host and the status only, so neither the
// token nor a server-echoed header can reach the cache or a log.
export async function getJson(
  d: UsageDeps,
  endpoint: string,
  headers: Record<string, string>,
): Promise<unknown> {
  const url = new URL(endpoint);
  assertEndpoint(url);
  let res: Response;
  try {
    res = await d.fetch(url, {
      headers,
      redirect: "error",
      signal: AbortSignal.timeout(HTTP_TIMEOUT_MS),
    });
  } catch {
    throw new ProbeError(`could not reach ${url.hostname}`);
  }
  if (res.status === 401 || res.status === 403) {
    throw new ProbeError(`${url.hostname} refused the sign-in (status ${res.status})`);
  }
  if (res.status === 429) throw new ProbeError(`${url.hostname} is rate limiting usage checks`);
  if (!res.ok) throw new ProbeError(`${url.hostname} answered status ${res.status}`);
  if (count(res.headers.get("content-length")) > MAX_BODY_BYTES) {
    await res.body?.cancel().catch(() => {});
    throw new ProbeError(`${url.hostname} answered too much`);
  }
  let text: string | null;
  try {
    text = await readStreamCapped(res.body, MAX_BODY_BYTES);
  } catch {
    throw new ProbeError(`${url.hostname} cut its answer short`);
  }
  if (text === null) throw new ProbeError(`${url.hostname} answered too much`);
  try {
    return JSON.parse(text);
  } catch {
    throw new ProbeError(`${url.hostname} answered invalid JSON`);
  }
}

// ── Claude Code ─────────────────────────────────────────────────────────────

function claudeLimit(label: string, bucket: unknown): UsageLimit | null {
  const b = obj(bucket);
  const used = Number(String(b.utilization ?? b.percent ?? "").replace("%", ""));
  if (b.utilization === null || !Number.isFinite(used) || used < 0) return null;
  return { label, percent: clamp01(used / 100), resetsAt: isoTime(b.resets_at, "auto") };
}

export function parseClaudeUsage(payload: unknown): UsageLimit[] {
  const p = obj(payload);
  const limits: UsageLimit[] = [];
  const session = claudeLimit("Session (5-hour)", p.five_hour);
  const weekly = claudeLimit("Weekly (7-day)", p.seven_day);
  if (session) limits.push(session);
  if (weekly) limits.push(weekly);
  const seen = new Set<string>();
  for (const entry of Array.isArray(p.limits) ? p.limits : []) {
    const e = obj(entry);
    const model = obj(obj(e.scope).model);
    const name = String(model.display_name ?? model.id ?? "").trim();
    const kind = String(e.kind ?? "").toLowerCase();
    const window = kind.includes("week") ? "Weekly" : kind.includes("hour") ? "Session" : "";
    const label = window ? `${name} ${window}` : name;
    if (name === "" || seen.has(label)) continue;
    const limit = claudeLimit(label, e);
    if (limit) {
      seen.add(label);
      limits.push(limit);
    }
  }
  return limits;
}

async function probeClaude(d: UsageDeps): Promise<Omit<ProbeResult, "at" | "fetchedAt"> | null> {
  const login = obj(obj(readJson(join(claudeDir(d), ".credentials.json"))).claudeAiOauth);
  const token = typeof login.accessToken === "string" ? login.accessToken : "";
  if (token === "") return null;
  const expiresAt = count(login.expiresAt);
  if (expiresAt > 0 && expiresAt <= d.now()) {
    throw new ProbeError("the Claude Code sign-in expired; start claude to renew it");
  }
  const payload = await getJson(d, ENDPOINTS.claude, {
    Authorization: `Bearer ${token}`,
    "anthropic-beta": "oauth-2025-04-20",
    Accept: "application/json",
  });
  const limits = parseClaudeUsage(payload);
  if (limits.length === 0) throw new ProbeError("api.anthropic.com answered without limits");
  return { ready: true, limits };
}

// ── Codex (app-server JSON-RPC) ─────────────────────────────────────────────

function codexWindow(window: unknown, prefix: string): UsageLimit | null {
  const w = obj(window);
  if (typeof w.usedPercent !== "number" || !Number.isFinite(w.usedPercent)) return null;
  const mins = count(w.windowDurationMins);
  let label = "Limit";
  if (mins === 10080) label = "Weekly (7-day)";
  else if (mins > 0 && mins % 60 === 0) label = `${mins / 60}h window`;
  else if (mins > 0) label = `${mins}m window`;
  return {
    label: prefix ? `${prefix} ${label}` : label,
    percent: clamp01(w.usedPercent / 100),
    resetsAt: isoTime(count(w.resetsAt) || "", "s"),
  };
}

export function parseCodexRateLimits(result: unknown): UsageLimit[] {
  const r = obj(result);
  const byId = obj(r.rateLimitsByLimitId);
  let buckets = Object.entries(byId).filter(([, v]) => Object.keys(obj(v)).length > 0);
  if (buckets.length === 0 && Object.keys(obj(r.rateLimits)).length > 0) {
    buckets = [["codex", r.rateLimits]];
  }
  buckets.sort(([a], [b]) => Number(a !== "codex") - Number(b !== "codex"));
  const limits: UsageLimit[] = [];
  for (const [id, raw] of buckets) {
    const bucket = obj(raw);
    const general = id === "codex" || (buckets.length === 1 && !bucket.limitName);
    const prefix = general ? "" : String(bucket.limitName ?? id).trim();
    for (const window of [bucket.primary, bucket.secondary]) {
      const limit = codexWindow(window, prefix);
      if (limit) limits.push(limit);
    }
  }
  return limits;
}

class LineReader {
  private buf = "";
  private readonly decoder = new TextDecoder();
  private readonly reader: { read(): Promise<{ done: boolean; value?: Uint8Array }> };

  constructor(stream: ReadableStream<Uint8Array>) {
    this.reader = stream.getReader();
  }

  async next(deadline: number): Promise<string | null> {
    for (;;) {
      const nl = this.buf.indexOf("\n");
      if (nl >= 0) {
        const line = this.buf.slice(0, nl);
        this.buf = this.buf.slice(nl + 1);
        return line;
      }
      const left = deadline - Date.now();
      if (left <= 0) throw new ProbeError("the Codex app-server did not answer in time");
      let timer: ReturnType<typeof setTimeout> | undefined;
      const timeout = new Promise<null>((resolve) => {
        timer = setTimeout(() => resolve(null), left);
      });
      const chunk = await Promise.race([this.reader.read(), timeout]);
      clearTimeout(timer);
      if (chunk === null) continue;
      if (chunk.done) return null;
      this.buf += this.decoder.decode(chunk.value, { stream: true });
      if (this.buf.length > MAX_RPC_LINE_CHARS && !this.buf.includes("\n")) {
        throw new ProbeError("the Codex app-server answered too much");
      }
    }
  }
}

async function rpcReply(lines: LineReader, id: number, deadline: number): Promise<unknown> {
  for (;;) {
    const line = await lines.next(deadline);
    if (line === null) throw new ProbeError("the Codex app-server exited early");
    let msg: unknown;
    try {
      msg = JSON.parse(line);
    } catch {
      continue;
    }
    if (obj(msg).id === id) return msg;
  }
}

const sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

// Close stdin, then SIGTERM, then SIGKILL after the grace; always reaped.
export async function stopProcess(
  proc: Bun.Subprocess<"pipe", "pipe", "ignore">,
  graceMs = RPC_KILL_GRACE_MS,
): Promise<void> {
  try {
    await proc.stdin.end();
  } catch {
    // already closed
  }
  if (proc.exitCode !== null || proc.signalCode !== null) return;
  proc.kill("SIGTERM");
  const exited = await Promise.race([proc.exited.then(() => true), sleep(graceMs).then(() => false)]);
  if (!exited) {
    proc.kill("SIGKILL");
    await proc.exited;
  }
}

export async function codexRpc(bin: string, env: UsageDeps["env"]): Promise<unknown> {
  const proc = Bun.spawn([bin, "-s", "read-only", "-a", "on-request", "app-server"], {
    stdin: "pipe",
    stdout: "pipe",
    stderr: "ignore",
    env: env as Record<string, string>,
  });
  const lines = new LineReader(proc.stdout);
  const deadline = Date.now() + RPC_TIMEOUT_MS;
  const send = (msg: unknown) => {
    proc.stdin.write(JSON.stringify(msg) + "\n");
    proc.stdin.flush();
  };
  try {
    const clientInfo = { name: "marchyo-agent-usage", version: "1" };
    send({ id: 1, method: "initialize", params: { clientInfo } });
    await rpcReply(lines, 1, deadline);
    send({ method: "initialized", params: {} });
    send({ id: 2, method: "account/rateLimits/read", params: {} });
    return await rpcReply(lines, 2, deadline);
  } finally {
    await stopProcess(proc);
  }
}

async function probeCodex(d: UsageDeps): Promise<Omit<ProbeResult, "at" | "fetchedAt"> | null> {
  const bin = findOnPath("codex", d.env.PATH);
  if (!bin) return null;
  if (!d.env.CODEX_ACCESS_TOKEN && !existsSync(join(codexHome(d), "auth.json"))) return null;
  const reply = obj(await codexRpc(bin, d.env));
  if (reply.error !== undefined) {
    const message = String(obj(reply.error).message ?? "").toLowerCase();
    throw new ProbeError(
      message.includes("auth") ? "Codex is not signed in; run codex login" : "the Codex app-server refused the limits request",
    );
  }
  const limits = parseCodexRateLimits(reply.result);
  if (limits.length === 0) throw new ProbeError("the Codex app-server answered without limits");
  return { ready: true, limits };
}

// ── GitHub Copilot ──────────────────────────────────────────────────────────

async function ghAuthToken(env: UsageDeps["env"]): Promise<string> {
  const gh = findOnPath("gh", env.PATH);
  if (!gh) return "";
  try {
    // --hostname keeps an Enterprise GH_HOST token away from api.github.com.
    const proc = Bun.spawn([gh, "auth", "token", "--hostname", "github.com"], {
      stdout: "pipe",
      stderr: "ignore",
      stdin: "ignore",
      env: env as Record<string, string>,
    });
    const timer = setTimeout(() => proc.kill("SIGKILL"), 5000);
    const out = await readStreamCapped(proc.stdout, 64 * 1024);
    clearTimeout(timer);
    return (await proc.exited) === 0 && out !== null ? out.trim() : "";
  } catch {
    return "";
  }
}

export function parseCopilotQuota(payload: unknown): UsageLimit[] {
  const p = obj(payload);
  const snap = obj(obj(p.quota_snapshots).premium_interactions);
  if (Object.keys(snap).length === 0 || snap.unlimited === true) return [];
  const entitlement = count(snap.entitlement);
  if (entitlement <= 0) return [];
  let used: number | null = snap.credits_used !== undefined ? count(snap.credits_used) : null;
  if (used === null && snap.remaining !== undefined) used = entitlement - count(snap.remaining);
  if (used === null && snap.percent_remaining !== undefined) {
    used = (entitlement * (100 - count(snap.percent_remaining))) / 100;
  }
  if (used === null) throw new ProbeError("api.github.com answered without a quota");
  return [
    {
      label: "Premium requests (monthly)",
      percent: clamp01(used / entitlement),
      resetsAt: isoTime(p.quota_reset_date_utc, "auto"),
    },
  ];
}

function envToken(env: UsageDeps["env"]): string {
  for (const key of ["COPILOT_QUOTA_TOKEN", "GH_TOKEN", "GITHUB_TOKEN"]) {
    const v = env[key]?.trim();
    if (v) return v;
  }
  return "";
}

async function probeCopilot(d: UsageDeps): Promise<Omit<ProbeResult, "at" | "fetchedAt"> | null> {
  // The quota probe hands a GitHub token to GitHub, so it runs only where the
  // Copilot CLI has been used.
  if (!existsSync(copilotHome(d))) return null;
  const token = envToken(d.env) || (await d.ghToken());
  if (token === "") throw new ProbeError("no GitHub token; run gh auth login");
  const payload = await getJson(d, ENDPOINTS.copilot, {
    Authorization: `Bearer ${token}`,
    Accept: "application/json",
    "User-Agent": "marchyo-agent-usage",
  });
  return { ready: true, limits: parseCopilotQuota(payload) };
}

// ── Z.ai Coding Plan ────────────────────────────────────────────────────────

const ZAI_WINDOWS: Record<string, string> = { "3:5": "Session (5-hour)", "6:1": "Weekly (7-day)" };
const ZAI_AUTH_CODES = new Set(["1000", "1001", "1003", "1005"]);

export function parseZaiQuota(payload: unknown): UsageLimit[] {
  const p = obj(payload);
  const code = String(p.code ?? "");
  if (ZAI_AUTH_CODES.has(code)) throw new ProbeError("api.z.ai refused the sign-in");
  const rows = obj(p.data).limits;
  if (!Array.isArray(rows)) {
    if (String(p.msg ?? "").toLowerCase().includes("coding plan")) return [];
    throw new ProbeError("api.z.ai answered without limits");
  }
  const limits: UsageLimit[] = [];
  for (const row of rows) {
    const r = obj(row);
    const label = ZAI_WINDOWS[`${r.unit}:${r.number}`];
    const pct = r.percentage;
    if (r.type !== "CREDIT_LIMIT" && r.type !== "TOKENS_LIMIT") continue;
    if (!label || typeof pct !== "number" || !Number.isFinite(pct)) continue;
    limits.push({ label, percent: clamp01(pct / 100), resetsAt: isoTime(r.nextResetTime, "auto") });
  }
  return limits;
}

async function probeZai(d: UsageDeps): Promise<Omit<ProbeResult, "at" | "fetchedAt"> | null> {
  const key = d.env.ZAI_API_KEY?.trim();
  if (!key) return null;
  // This endpoint takes the raw key, not a Bearer prefix.
  const payload = await getJson(d, ENDPOINTS.zai, { Authorization: key, Accept: "application/json" });
  return { ready: true, limits: parseZaiQuota(payload) };
}

// ── OpenRouter key limit ────────────────────────────────────────────────────

const OPENROUTER_PERIODS: Record<string, string> = { daily: "Daily", weekly: "Weekly", monthly: "Monthly" };

export function parseOpenRouterKey(payload: unknown): UsageLimit[] {
  const key = obj(obj(payload).data);
  if (!("limit" in key)) throw new ProbeError("openrouter.ai answered without a key limit");
  if (key.limit === null) return [];
  const limit = typeof key.limit === "number" ? key.limit : NaN;
  const remaining = typeof key.limit_remaining === "number" ? key.limit_remaining : NaN;
  if (!Number.isFinite(limit) || !Number.isFinite(remaining)) {
    throw new ProbeError("openrouter.ai answered with an unreadable key limit");
  }
  if (limit <= 0) return [];
  const period = OPENROUTER_PERIODS[String(key.limit_reset ?? "").toLowerCase()];
  const label = period ? `${period} key limit` : "Key limit";
  return [{ label, percent: clamp01((limit - Math.min(Math.max(remaining, 0), limit)) / limit), resetsAt: "" }];
}

async function probeOpenRouter(d: UsageDeps): Promise<Omit<ProbeResult, "at" | "fetchedAt"> | null> {
  const key = d.env.OPENROUTER_API_KEY?.trim();
  if (!key) return null;
  const payload = await getJson(d, ENDPOINTS.openrouter, {
    Authorization: `Bearer ${key}`,
    Accept: "application/json",
  });
  return { ready: true, limits: parseOpenRouterKey(payload) };
}

// ── transcript scans ────────────────────────────────────────────────────────

function emptyTotals(): DayTotals {
  return { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0, cost: 0 };
}

function addTo(days: Days, day: string, t: Partial<DayTotals>): void {
  const cur = (days[day] ??= emptyTotals());
  cur.input += t.input ?? 0;
  cur.output += t.output ?? 0;
  cur.cacheRead += t.cacheRead ?? 0;
  cur.cacheWrite += t.cacheWrite ?? 0;
  cur.total += (t.input ?? 0) + (t.output ?? 0) + (t.cacheRead ?? 0) + (t.cacheWrite ?? 0);
  cur.cost += t.cost ?? 0;
}

function accumulate(cur: DayTotals, t: DayTotals): void {
  cur.input += t.input;
  cur.output += t.output;
  cur.cacheRead += t.cacheRead;
  cur.cacheWrite += t.cacheWrite;
  cur.total += t.total;
  cur.cost += t.cost;
}

function mergeDays(into: Days, from: Days): void {
  for (const [day, t] of Object.entries(from)) accumulate((into[day] ??= emptyTotals()), t);
}

function eventDay(timestamp: unknown, fallback: number): string {
  const t = typeof timestamp === "string" ? Date.parse(timestamp) : NaN;
  return localDay(Number.isNaN(t) ? fallback : t);
}

// Lines of `text` up to MAX_LINE_CHARS each; longer lines are skipped.
export function* textLines(text: string): Generator<string> {
  let start = 0;
  while (start < text.length) {
    let nl = text.indexOf("\n", start);
    if (nl < 0) nl = text.length;
    if (nl - start <= MAX_LINE_CHARS) yield text.slice(start, nl);
    start = nl + 1;
  }
}

// Lines of a plain file, streamed in chunks: at most MAX_TRANSCRIPT_BYTES are
// read, and a line longer than MAX_LINE_CHARS is dropped whole.
export function* fileLines(path: string): Generator<string> {
  const fd = openSync(path, constants.O_RDONLY | constants.O_NOFOLLOW);
  const decoder = new TextDecoder();
  const buf = Buffer.allocUnsafe(READ_CHUNK);
  let pending = "";
  let skipping = false;
  let total = 0;
  try {
    while (total < MAX_TRANSCRIPT_BYTES) {
      const n = readSync(fd, buf, 0, Math.min(READ_CHUNK, MAX_TRANSCRIPT_BYTES - total), null);
      if (n === 0) break;
      total += n;
      pending += decoder.decode(buf.subarray(0, n), { stream: true });
      let start = 0;
      for (let nl = pending.indexOf("\n"); nl >= 0; nl = pending.indexOf("\n", start)) {
        if (!skipping && nl - start <= MAX_LINE_CHARS) yield pending.slice(start, nl);
        skipping = false;
        start = nl + 1;
      }
      pending = pending.slice(start);
      if (pending.length > MAX_LINE_CHARS) {
        pending = "";
        skipping = true;
      }
    }
    if (!skipping && pending !== "" && total < MAX_TRANSCRIPT_BYTES) yield pending;
  } finally {
    closeSync(fd);
  }
}

function* jsonLines(lines: Iterable<string>, marker: string): Generator<Record<string, unknown>> {
  for (const line of lines) {
    if (!line.includes(marker)) continue;
    try {
      yield obj(JSON.parse(line));
    } catch {
      // a torn line from a session still being written
    }
  }
}

// Claude Code writes one line per content block, each repeating the reply's
// usage, so a reply counts once by message id and request id.
export function scanClaudeTranscript(text: string | Iterable<string>, mtimeMs: number): Days {
  const days: Days = {};
  const seen = new Set<string>();
  const lines = typeof text === "string" ? textLines(text) : text;
  for (const entry of jsonLines(lines, '"assistant"')) {
    if (entry.type !== "assistant") continue;
    const message = obj(entry.message);
    const usage = obj(message.usage);
    if (Object.keys(usage).length === 0) continue;
    const key = `${String(message.id ?? "")}:${String(entry.requestId ?? "")}`;
    if (key !== ":" && seen.has(key)) continue;
    seen.add(key);
    addTo(days, eventDay(entry.timestamp, mtimeMs), {
      input: count(usage.input_tokens),
      output: count(usage.output_tokens),
      cacheRead: count(usage.cache_read_input_tokens),
      cacheWrite: count(usage.cache_creation_input_tokens),
      cost: count(entry.costUSD),
    });
  }
  return days;
}

// Codex rollouts carry running totals in token_count events; each event's
// growth over the previous one is booked on the event's day.
export function scanCodexRollout(text: string | Iterable<string>, mtimeMs: number): Days {
  const days: Days = {};
  let prev = { input: 0, cached: 0, write: 0, output: 0 };
  const lines = typeof text === "string" ? textLines(text) : text;
  for (const entry of jsonLines(lines, '"token_count"')) {
    const payload = obj(entry.payload);
    if (payload.type !== "token_count") continue;
    const total = obj(obj(payload.info).total_token_usage);
    if (Object.keys(total).length === 0) continue;
    const cur = {
      input: count(total.input_tokens),
      cached: count(total.cached_input_tokens),
      write: count(total.cache_write_input_tokens),
      output: count(total.output_tokens),
    };
    const restarted = cur.input + cur.output < prev.input + prev.output;
    const base = restarted ? { input: 0, cached: 0, write: 0, output: 0 } : prev;
    const cached = Math.max(0, cur.cached - base.cached);
    const write = Math.max(0, cur.write - base.write);
    addTo(days, eventDay(entry.timestamp, mtimeMs), {
      input: Math.max(0, cur.input - base.input - cached - write),
      cacheRead: cached,
      cacheWrite: write,
      output: Math.max(0, cur.output - base.output),
    });
    prev = cur;
  }
  return days;
}

// A transcript's lines; a .zst one is decompressed to at most
// MAX_TRANSCRIPT_BYTES, and one that would inflate past it is skipped.
function transcriptLines(path: string): Iterable<string> | null {
  if (!path.endsWith(".zst")) return fileLines(path);
  const raw = readFileCapped(path, MAX_TRANSCRIPT_BYTES, constants.O_RDONLY | constants.O_NOFOLLOW);
  if (raw === null) return null;
  try {
    return textLines(zstdDecompressSync(raw, { maxOutputLength: MAX_TRANSCRIPT_BYTES }).toString("utf8"));
  } catch {
    return null;
  }
}

// Matching files modified since `since`, newest first, at most MAX_SCAN_FILES.
export function recentFiles(root: string, accept: (name: string) => boolean, since: number): string[] {
  const found: { path: string; mtimeMs: number }[] = [];
  const walk = (dir: string, depth: number) => {
    let entries;
    try {
      entries = readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const e of entries) {
      if (found.length >= MAX_SCAN_FILES * 2) return;
      const p = join(dir, e.name);
      if (e.isDirectory() && depth < 6) walk(p, depth + 1);
      else if (e.isFile() && accept(e.name)) {
        try {
          const mtimeMs = statSync(p).mtimeMs;
          if (mtimeMs >= since) found.push({ path: p, mtimeMs });
        } catch {
          // vanished mid-walk
        }
      }
    }
  };
  walk(root, 0);
  found.sort((a, b) => b.mtimeMs - a.mtimeMs);
  return found.slice(0, MAX_SCAN_FILES).map((f) => f.path);
}

interface IndexEntry {
  size: number;
  mtimeMs: number;
  days: Days;
}
type ScanIndex = Record<string, IndexEntry>;

// Each transcript is parsed again only when its size or mtime moved.
function scanFiles(
  files: string[],
  parse: (lines: Iterable<string>, mtimeMs: number) => Days,
  index: ScanIndex,
  next: ScanIndex,
): Days {
  const days: Days = {};
  for (const path of files) {
    let st;
    try {
      st = statSync(path);
    } catch {
      continue;
    }
    let entry = index[path];
    if (!entry || entry.size !== st.size || entry.mtimeMs !== st.mtimeMs) {
      let parsed: Days;
      try {
        const lines = transcriptLines(path);
        if (lines === null) continue;
        parsed = parse(lines, st.mtimeMs);
      } catch {
        continue; // unreadable, a symlink, or gone mid-read
      }
      entry = { size: st.size, mtimeMs: st.mtimeMs, days: parsed };
    }
    next[path] = entry;
    mergeDays(days, entry.days);
  }
  return days;
}

export function scanOpencode(dbPath: string, since: number): Days {
  const days: Days = {};
  if (!existsSync(dbPath)) return days;
  let db: Database | undefined;
  try {
    db = new Database(dbPath, { readonly: true });
    const rows = db
      .query(
        `SELECT time_created AS t,
           json_extract(data, '$.tokens.input') AS i,
           json_extract(data, '$.tokens.output') AS o,
           json_extract(data, '$.tokens.reasoning') AS r,
           json_extract(data, '$.tokens.cache.read') AS cr,
           json_extract(data, '$.tokens.cache.write') AS cw,
           json_extract(data, '$.cost') AS c
         FROM message
         WHERE time_created >= ? AND json_extract(data, '$.role') = 'assistant'`,
      )
      .all(since) as Record<string, unknown>[];
    for (const row of rows) {
      const t = count(row.t);
      if (t === 0) continue;
      addTo(days, localDay(t), {
        input: count(row.i),
        output: count(row.o) + count(row.r),
        cacheRead: count(row.cr),
        cacheWrite: count(row.cw),
        cost: count(row.c),
      });
    }
  } catch {
    // an unreadable or older store counts nothing
  } finally {
    db?.close();
  }
  return days;
}

// `indexPath` null (an unsafe state dir) scans without the index.
function scanAll(d: UsageDeps, indexPath: string | null): Partial<Record<ScannedId, Days>> {
  const since = d.now() - SCAN_WINDOW_DAYS * DAY_MS;
  const index = indexPath === null ? {} : readScanIndex(indexPath);
  const next: ScanIndex = {};
  const claude = scanFiles(
    recentFiles(join(claudeDir(d), "projects"), (n) => n.endsWith(".jsonl"), since),
    scanClaudeTranscript,
    index,
    next,
  );
  const rollout = (n: string) => n.startsWith("rollout-") && /\.jsonl(\.zst)?$/.test(n);
  const codex = scanFiles(
    recentFiles(join(codexHome(d), "sessions"), rollout, since),
    scanCodexRollout,
    index,
    next,
  );
  if (indexPath !== null) {
    try {
      writePrivate(indexPath, JSON.stringify(next));
    } catch {
      // the next run re-reads the transcripts
    }
  }
  return { claude, codex, opencode: scanOpencode(opencodeDb(d), since) };
}

// ── summary ─────────────────────────────────────────────────────────────────

function summarize(days: Days | undefined, now: number): Pick<AgentUsage, "tokens" | "cost"> {
  if (!days) return {};
  const today = localDay(now);
  const since = localDay(now - (SCAN_WINDOW_DAYS - 1) * DAY_MS);
  const t = emptyTotals();
  const last = emptyTotals();
  for (const [day, v] of Object.entries(days)) {
    if (day < since) continue;
    accumulate(last, v);
    if (day === today) accumulate(t, v);
  }
  if (last.total === 0) return {};
  const strip = ({ cost: _c, ...rest }: DayTotals): TokenTotals => rest;
  const out: Pick<AgentUsage, "tokens" | "cost"> = {
    tokens: { today: strip(t), last30Days: strip(last) },
  };
  if (last.cost > 0) out.cost = { currency: "USD", today: t.cost, last30Days: last.cost };
  return out;
}

// ── orchestration ───────────────────────────────────────────────────────────

const PROBES: Record<ProbedId, (d: UsageDeps) => Promise<Omit<ProbeResult, "at" | "fetchedAt"> | null>> = {
  claude: probeClaude,
  codex: probeCodex,
  copilot: probeCopilot,
  zai: probeZai,
  openrouter: probeOpenRouter,
};

function fresh(at: number | undefined, now: number, window: number): boolean {
  if (at === undefined) return false;
  const age = now - at;
  return age >= 0 && age < window;
}

async function runProbe(d: UsageDeps, id: ProbedId, prev?: ProbeResult): Promise<ProbeResult> {
  const at = d.now();
  try {
    const r = await PROBES[id](d);
    if (r === null) return { at, ready: false, limits: [], fetchedAt: 0 };
    return { ...r, at, fetchedAt: at };
  } catch (e) {
    const error = e instanceof ProbeError ? e.message : "the usage check failed";
    // The last good limits stay on show, marked by the error and their age.
    return { at, ready: true, limits: prev?.limits ?? [], fetchedAt: prev?.fetchedAt ?? 0, error };
  }
}

// ── state files ─────────────────────────────────────────────────────────────
//
// Both files are this CLI's own output read back, but another process can
// write them, so every entry is validated and a bad one is dropped.

const num = z.number().finite().nonnegative();
const LimitSchema = z.object({ label: z.string(), percent: z.number().min(0).max(1), resetsAt: z.string() });
const ProbeSchema = z.object({
  at: num,
  ready: z.boolean(),
  limits: z.array(LimitSchema),
  fetchedAt: num,
  error: z.string().optional(),
});
const DaySchema = z.object({
  input: num,
  output: num,
  cacheRead: num,
  cacheWrite: num,
  total: num,
  cost: num,
});
const TotalsSchema = DaySchema.omit({ cost: true });
const AgentSchema = z.object({
  id: z.enum(AGENT_IDS),
  name: z.string(),
  ready: z.boolean(),
  limits: z.array(LimitSchema),
  limitsFetchedAt: num,
  tokens: z.object({ today: TotalsSchema, last30Days: TotalsSchema }).optional(),
  cost: z.object({ currency: z.literal("USD"), today: num, last30Days: num }).optional(),
  error: z.string().optional(),
});
const ACCOUNT_ID = z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/);
const ACCOUNT_PROBE_KEY = /^(?:claude|codex):[a-z0-9]+(?:-[a-z0-9]+)*$/;
const AccountUsageSchema = z.object({
  id: ACCOUNT_ID,
  label: z.string(),
  email: z.string(),
  plan: z.string(),
  primary: z.boolean(),
  active: z.boolean(),
  signedIn: z.boolean(),
  limits: z.array(LimitSchema),
  limitsFetchedAt: num,
  error: z.string().optional(),
});
const OfferSide = z.object({ id: ACCOUNT_ID, label: z.string() });
const ProviderAccountsSchema = z.object({
  provider: z.enum(ACCOUNT_PROVIDERS),
  name: z.string(),
  active: z.string(),
  switch: z.enum(["manual", "auto"]),
  threshold: num,
  accounts: z.array(AccountUsageSchema),
  offer: z
    .object({ alert: z.string(), from: OfferSide, to: OfferSide, fromPercent: num, toPercent: num })
    .optional(),
});
const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;
const IndexEntrySchema = z.object({ size: num, mtimeMs: num, days: z.record(z.string(), z.unknown()) });

function validEntries<T>(value: unknown, schema: z.ZodType<T>, key = (_k: string) => true): Record<string, T> {
  const out: Record<string, T> = {};
  for (const [k, v] of Object.entries(obj(value))) {
    if (!key(k)) continue;
    const r = schema.safeParse(v);
    if (r.success) out[k] = r.data;
  }
  return out;
}

function validDays(value: unknown): Days {
  return validEntries(value, DaySchema, (k) => DAY_RE.test(k));
}

function readScanIndex(path: string): ScanIndex {
  const out: ScanIndex = {};
  const raw = readJson(path, MAX_STATE_BYTES, constants.O_RDONLY | constants.O_NOFOLLOW);
  for (const [p, entry] of Object.entries(validEntries(raw, IndexEntrySchema))) {
    out[p] = { size: entry.size, mtimeMs: entry.mtimeMs, days: validDays(entry.days) };
  }
  return out;
}

function emptyUsageFile(): UsageFile {
  return {
    schemaVersion: USAGE_SCHEMA_VERSION,
    updatedAt: "",
    agents: [],
    accounts: [],
    scannedAt: 0,
    probes: {},
    scans: {},
  };
}

export function readUsageFile(path: string): UsageFile {
  const raw = obj(readJson(path, MAX_STATE_BYTES, constants.O_RDONLY | constants.O_NOFOLLOW));
  if (raw.schemaVersion !== USAGE_SCHEMA_VERSION) return emptyUsageFile();
  const agents = (Array.isArray(raw.agents) ? raw.agents : []).flatMap((a) => {
    const r = AgentSchema.safeParse(a);
    return r.success ? [r.data as AgentUsage] : [];
  });
  const probes = validEntries(
    raw.probes,
    ProbeSchema,
    (k) => Object.hasOwn(PROBES, k) || ACCOUNT_PROBE_KEY.test(k),
  ) as UsageFile["probes"];
  const accounts = (Array.isArray(raw.accounts) ? raw.accounts : []).flatMap((a) => {
    const r = ProviderAccountsSchema.safeParse(a);
    return r.success ? [r.data as ProviderAccountsUsage] : [];
  });
  const scans: UsageFile["scans"] = {};
  for (const [id, days] of Object.entries(obj(raw.scans))) {
    if (id === "claude" || id === "codex" || id === "opencode") scans[id] = validDays(days);
  }
  return {
    schemaVersion: USAGE_SCHEMA_VERSION,
    updatedAt: typeof raw.updatedAt === "string" ? raw.updatedAt : "",
    agents,
    accounts,
    scannedAt: count(raw.scannedAt),
    probes,
    scans,
  };
}

// The state dir must be a real directory owned by this user; a group- or
// world-writable one is tightened to 0700. Returns why it is unusable, or null.
export function checkStateDir(dir: string): string | null {
  try {
    mkdirSync(dir, { recursive: true, mode: 0o700 });
    const st = lstatSync(dir);
    if (!st.isDirectory()) return `${dir} is not a directory`;
    if (typeof process.getuid === "function" && st.uid !== process.getuid()) {
      return `${dir} is not owned by this user`;
    }
    if ((st.mode & 0o077) !== 0) chmodSync(dir, 0o700);
    return null;
  } catch {
    return `${dir} is not usable`;
  }
}

// Written to a fresh O_EXCL|O_NOFOLLOW temp file beside `path`, then renamed.
function writePrivate(path: string, text: string): void {
  const dir = path.slice(0, path.lastIndexOf("/"));
  const base = path.slice(dir.length + 1);
  const tmp = join(dir, `.${base}.${randomBytes(8).toString("hex")}.tmp`);
  const flags = constants.O_WRONLY | constants.O_CREAT | constants.O_EXCL | constants.O_NOFOLLOW;
  const fd = openSync(tmp, flags, 0o600);
  try {
    const data = Buffer.from(text, "utf8");
    let off = 0;
    while (off < data.length) off += writeSync(fd, data, off, data.length - off);
    closeSync(fd);
    renameSync(tmp, path);
  } catch (e) {
    try {
      closeSync(fd);
    } catch {
      // closed above
    }
    try {
      unlinkSync(tmp);
    } catch {
      // renamed or never written
    }
    throw e;
  }
}

function buildAgent(id: AgentId, probe: ProbeResult | undefined, days: Days | undefined, now: number): AgentUsage {
  const stats = summarize(days, now);
  const agent: AgentUsage = {
    id,
    name: AGENT_NAMES[id],
    ready: Boolean(probe?.ready) || stats.tokens !== undefined,
    limits: probe?.limits ?? [],
    limitsFetchedAt: probe?.fetchedAt ?? 0,
    ...stats,
  };
  if (probe?.error) agent.error = probe.error;
  return agent;
}

// ── accounts ────────────────────────────────────────────────────────────────

export function probeKey(p: AccountProvider, a: Pick<Account, "primary" | "home">): string {
  return a.primary ? p : `${p}:${basename(a.home)}`;
}

function withEnv(env: UsageDeps["env"], set: Record<string, string | undefined>): UsageDeps["env"] {
  const out = { ...env };
  for (const [k, v] of Object.entries(set)) {
    if (v === undefined) delete out[k];
    else out[k] = v;
  }
  return out;
}

interface ProbeTarget {
  id: ProbedId;
  key: string;
  deps: UsageDeps;
}

// Each account is probed in its own home, as a session started as that
// account sees it. The pin keeps the agent wrapper on the same home.
function accounted(id: ProbedId): id is AccountedId {
  return id === "claude" || id === "codex";
}

function probeTargets(d: UsageDeps, id: ProbedId): ProbeTarget[] {
  if (!accounted(id) || !hasRegistry(d, id)) return [{ id, key: id, deps: d }];
  const homeEnv = PROVIDER_SPECS[id].homeEnv;
  const pin = `MARCHYO_AGENT_${id.toUpperCase()}_HOME`;
  return loadRegistry(d, id).accounts.map((a) => {
    const home = a.primary ? undefined : a.home;
    const env = withEnv(d.env, { [homeEnv]: home, [pin]: home ?? "" });
    return { id, key: probeKey(id, a), deps: { ...d, env } };
  });
}

function limitsById(
  d: UsageDeps,
  p: AccountProvider,
  probes: Record<string, ProbeResult>,
): Record<string, UsageLimit[]> {
  const out: Record<string, UsageLimit[]> = {};
  for (const a of loadRegistry(d, p).accounts) {
    const probe = probes[probeKey(p, a)];
    if (probe?.ready && probe.fetchedAt > 0) out[a.id] = probe.limits;
  }
  return out;
}

function accountsView(
  d: UsageDeps,
  p: AccountProvider,
  probes: Record<string, ProbeResult>,
  offer?: SwitchOffer,
): ProviderAccountsUsage {
  const r = loadRegistry(d, p);
  const summary = summarizeRegistry(d, p, r);
  const accounts = summary.accounts.map(({ home: _home, ...rest }, i): AccountUsage => {
    const probe = probes[probeKey(p, r.accounts[i]!)];
    const view: AccountUsage = { ...rest, limits: probe?.limits ?? [], limitsFetchedAt: probe?.fetchedAt ?? 0 };
    if (probe?.error) view.error = probe.error;
    return view;
  });
  const view: ProviderAccountsUsage = { ...summary, accounts };
  if (offer) view.offer = offer;
  return view;
}

// After the probes: the switch policy for each provider with accounts, then
// the panel's account lists.
function settleAccounts(d: UsageDeps, probes: Record<string, ProbeResult>, now: number): ProviderAccountsUsage[] {
  const views: ProviderAccountsUsage[] = [];
  for (const p of ACCOUNT_PROVIDERS) {
    if (!hasRegistry(d, p)) continue;
    let offer: SwitchOffer | undefined;
    try {
      const result = applyAutoswitch(d, p, limitsById(d, p, probes), now);
      offer = result.offer;
      if (result.message) d.notify(result.message.title, result.message.body);
    } catch {
      // a busy registry switches on the next refresh
    }
    views.push(accountsView(d, p, probes, offer));
  }
  return views;
}

function activeProbe(d: UsageDeps, id: ProbedId, probes: Record<string, ProbeResult>): ProbeResult | undefined {
  if (!accounted(id) || !hasRegistry(d, id)) return probes[id];
  return probes[probeKey(id, activeAccount(loadRegistry(d, id)))];
}

export async function collectUsage(
  d: UsageDeps = defaultUsageDeps(),
  opts: { force?: boolean } = {},
): Promise<UsageFile> {
  const dir = usageDir(d.env, d.home);
  const path = join(dir, "usage.json");
  let stateError = checkStateDir(dir);
  const prev = stateError === null ? readUsageFile(path) : emptyUsageFile();
  const now = d.now();
  const reuseScan = !opts.force && fresh(prev.scannedAt, now, SCAN_REUSE_MS);
  const indexPath = stateError === null ? join(dir, "scan-index.json") : null;
  const scans = reuseScan ? prev.scans : scanAll(d, indexPath);
  const ids = Object.keys(PROBES) as ProbedId[];
  const targets = ids.flatMap((id) => probeTargets(d, id));
  const probes: Record<string, ProbeResult> = Object.fromEntries(
    await Promise.all(
      targets.map(async ({ id, key, deps }) => {
        const old = prev.probes[key];
        // The floor holds for --force too: refresh clicks never hammer a provider.
        const keep = old && fresh(old.at, now, PROBE_MIN_INTERVAL_MS);
        return [key, keep ? old : await runProbe(deps, id, old)] as const;
      }),
    ),
  );
  const accounts = settleAccounts(d, probes, now);
  const agents = AGENT_IDS.map((id) =>
    buildAgent(id, id === "opencode" ? undefined : activeProbe(d, id, probes), scans[id as ScannedId], now),
  );
  const file: UsageFile = {
    schemaVersion: USAGE_SCHEMA_VERSION,
    updatedAt: new Date(now).toISOString(),
    agents,
    accounts,
    scannedAt: reuseScan ? prev.scannedAt : now,
    probes,
    scans,
  };
  if (stateError === null) {
    try {
      writePrivate(path, JSON.stringify(file));
    } catch {
      stateError = `could not write ${path}`;
    }
  }
  if (stateError !== null) file.stateError = stateError;
  return file;
}

import { createHash } from "node:crypto";
import {
  chmodSync,
  closeSync,
  existsSync,
  lstatSync,
  mkdirSync,
  mkdtempSync,
  openSync,
  readdirSync,
  readFileSync,
  renameSync,
  rmSync,
  statSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import type { UsageLimit } from "./agent-usage.ts";

// Several Claude Code, Codex and Grok sign-ins on one machine. The login the
// CLI made first stays in its own home (~/.claude, ~/.codex, ~/.grok) and is
// the primary account. An added account gets a home under
// $XDG_STATE_HOME/marchyo/agents/accounts/<provider>/<id>/ that holds only its
// credentials; everything else links back to the primary home, so history,
// settings and sessions stay one set. A launch selects an account with
// CLAUDE_CONFIG_DIR / CODEX_HOME / GROK_HOME. Credentials are read and written
// here only: the registry, the usage record and the output hold display-safe
// identity (label, email, plan), never a token.

export const ACCOUNT_PROVIDERS = ["claude", "codex", "grok"] as const;
export type AccountProvider = (typeof ACCOUNT_PROVIDERS)[number];
export const SWITCH_MODES = ["manual", "auto"] as const;
export type SwitchMode = (typeof SWITCH_MODES)[number];
export const REGISTRY_SCHEMA_VERSION = 1;
export const DEFAULT_THRESHOLD = 95;
export const MAX_TRANSFER_BYTES = 8 * 1024 * 1024;
// `next` cycles, a provider name reads as the provider, `primary` names the
// first login whatever it is called now.
const RESERVED_IDS = new Set(["next", "add", "primary", ...ACCOUNT_PROVIDERS]);
// An account within this many points of the threshold is near its limit.
const NEAR_MARGIN = 15;
const LOCK_WAIT_MS = 5_000;
const LOCK_STALE_MS = 30_000;

interface ProviderSpec {
  name: string;
  homeEnv: string;
  login: string[];
  sharedDirs: string[];
  sharedFiles: string[];
  credentialFiles: string[];
  // Keys a new Claude account takes from the primary ~/.claude.json, so MCP
  // servers, folder trust and onboarding carry over.
  carriedKeys: string[];
}

export const PROVIDER_SPECS: Record<AccountProvider, ProviderSpec> = {
  claude: {
    name: "Claude Code",
    homeEnv: "CLAUDE_CONFIG_DIR",
    login: ["claude", "auth", "login"],
    sharedDirs: [
      "projects",
      "skills",
      "agents",
      "commands",
      "plugins",
      "hooks",
      "themes",
      "output-styles",
      "file-history",
      "todos",
      "plans",
    ],
    sharedFiles: ["settings.json", "CLAUDE.md", "history.jsonl", "keybindings.json"],
    credentialFiles: [".credentials.json", ".claude.json"],
    carriedKeys: ["mcpServers", "projects", "theme", "hasCompletedOnboarding", "lastOnboardingVersion", "editorMode"],
  },
  codex: {
    name: "Codex",
    homeEnv: "CODEX_HOME",
    login: ["codex", "login"],
    sharedDirs: ["sessions", "archived_sessions", "prompts", "skills", "rules", "plugins"],
    sharedFiles: ["config.toml", "AGENTS.md", "history.jsonl", "hooks.json"],
    credentialFiles: ["auth.json"],
    carriedKeys: [],
  },
  grok: {
    name: "Grok",
    homeEnv: "GROK_HOME",
    login: ["grok", "login"],
    sharedDirs: [
      "sessions",
      "skills",
      "agents",
      "plugins",
      "installed-plugins",
      "marketplace-cache",
      "hooks",
      "memory",
      "memory-v2",
      "rules",
      "commands",
      "workflows",
      "personas",
      "worktrees",
    ],
    sharedFiles: [
      "config.toml",
      "settings.json",
      "lsp.json",
      "pager.toml",
      "sandbox.toml",
      "trusted_folders.toml",
      "statusline.sh",
      "worktrees.db",
    ],
    credentialFiles: ["auth.json", "settings_cache.json"],
    carriedKeys: [],
  },
};

export class AccountError extends Error {}

// The import found accounts it would overwrite; nothing was written.
export class TransferConflict extends AccountError {
  constructor(readonly conflicts: string[]) {
    super(`would replace the sign-in of ${conflicts.join(", ")}`);
  }
}

export interface AccountsDeps {
  env: Record<string, string | undefined>;
  home: string;
  procRoot: string;
}

export function defaultAccountsDeps(): AccountsDeps {
  return { env: process.env, home: homedir(), procRoot: "/proc" };
}

export interface Account {
  id: string;
  label: string;
  primary: boolean;
  home: string;
  accountId: string;
  email: string;
  plan: string;
}

export interface Registry {
  schemaVersion: number;
  active: string;
  switch: SwitchMode;
  threshold: number;
  alert: string;
  accounts: Account[];
}

export interface AccountSummary {
  id: string;
  label: string;
  email: string;
  plan: string;
  primary: boolean;
  active: boolean;
  signedIn: boolean;
  home: string;
}

export interface ProviderAccounts {
  provider: AccountProvider;
  name: string;
  active: string;
  switch: SwitchMode;
  threshold: number;
  accounts: AccountSummary[];
}

export function isAccountProvider(value: string): value is AccountProvider {
  return (ACCOUNT_PROVIDERS as readonly string[]).includes(value);
}

// ── paths ───────────────────────────────────────────────────────────────────

export function accountsRoot(d: Pick<AccountsDeps, "env" | "home">): string {
  const state = d.env.XDG_STATE_HOME || join(d.home, ".local", "state");
  return join(state, "marchyo", "agents", "accounts");
}

export function registryPath(d: Pick<AccountsDeps, "env" | "home">, p: AccountProvider): string {
  return join(accountsRoot(d), `${p}.json`);
}

export function hasRegistry(d: Pick<AccountsDeps, "env" | "home">, p: AccountProvider): boolean {
  return existsSync(registryPath(d, p));
}

// Where the CLI keeps a login when nothing points it elsewhere. It is not
// read from CLAUDE_CONFIG_DIR and friends: those select an added account.
export function primaryHome(d: Pick<AccountsDeps, "home">, p: AccountProvider): string {
  return join(d.home, `.${p}`);
}

// An added account's home is a direct child of its provider's directory; a
// registry entry that points anywhere else is ignored.
function ownedHome(d: Pick<AccountsDeps, "env" | "home">, p: AccountProvider, home: string): boolean {
  const root = join(accountsRoot(d), p);
  return home === resolve(home) && dirname(home) === root && !home.endsWith("/.pending");
}

export function accountHome(d: Pick<AccountsDeps, "env" | "home">, p: AccountProvider, a: Account): string {
  return a.primary ? primaryHome(d, p) : a.home;
}

// Claude keeps its account file beside the default home and inside any other.
function claudeAccountFile(d: Pick<AccountsDeps, "home">, home: string): string {
  return home === primaryHome(d, "claude") ? join(d.home, ".claude.json") : join(home, ".claude.json");
}

function credentialPath(d: Pick<AccountsDeps, "home">, p: AccountProvider, home: string, name: string): string {
  return p === "claude" && name === ".claude.json" ? claudeAccountFile(d, home) : join(home, name);
}

// ── files ───────────────────────────────────────────────────────────────────

function obj(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function str(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function readJson(path: string): unknown {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch {
    return null;
  }
}

function readText(path: string): string | null {
  try {
    return readFileSync(path, "utf8");
  } catch {
    return null;
  }
}

export function writePrivateFile(path: string, text: string): void {
  const dir = dirname(path);
  mkdirSync(dir, { recursive: true, mode: 0o700 });
  const tmp = join(dir, `.marchyo-${process.pid}-${Math.random().toString(36).slice(2)}.tmp`);
  try {
    writeFileSync(tmp, text, { mode: 0o600 });
    chmodSync(tmp, 0o600);
    renameSync(tmp, path);
  } finally {
    rmSync(tmp, { force: true });
  }
}

function exists(path: string): boolean {
  try {
    lstatSync(path);
    return true;
  } catch {
    return false;
  }
}

// ── identity ────────────────────────────────────────────────────────────────

export interface Identity {
  accountId: string;
  email: string;
  plan: string;
  signedIn: boolean;
}

const NOBODY: Identity = { accountId: "", email: "", plan: "", signedIn: false };

function jwtClaims(token: string): Record<string, unknown> {
  try {
    const part = token.split(".")[1] ?? "";
    return obj(JSON.parse(Buffer.from(part, "base64url").toString("utf8")));
  } catch {
    return {};
  }
}

function capitalize(s: string): string {
  return s ? s[0]!.toUpperCase() + s.slice(1) : "";
}

function shortHash(text: string): string {
  return createHash("sha256").update(text).digest("hex").slice(0, 16);
}

function claudeIdentity(d: Pick<AccountsDeps, "home">, home: string): Identity {
  const account = obj(obj(readJson(claudeAccountFile(d, home))).oauthAccount);
  const login = obj(obj(readJson(join(home, ".credentials.json"))).claudeAiOauth);
  const tier = /max_(\d+x)/i.exec(str(login.rateLimitTier));
  const accountId = str(account.accountUuid);
  return {
    accountId,
    email: str(account.emailAddress),
    plan: tier ? `Max ${tier[1]}` : capitalize(str(login.subscriptionType)),
    signedIn: accountId !== "" && (str(login.accessToken) !== "" || str(login.refreshToken) !== ""),
  };
}

function codexIdentity(home: string): Identity {
  const auth = obj(readJson(join(home, "auth.json")));
  const tokens = obj(auth.tokens);
  const claims = jwtClaims(str(tokens.id_token));
  const openai = obj(claims["https://api.openai.com/auth"]);
  const apiKey = str(auth.OPENAI_API_KEY);
  const accountId =
    str(tokens.account_id) || str(openai.chatgpt_account_id) || (apiKey ? `key-${shortHash(apiKey)}` : "");
  const signedIn = accountId !== "" && (str(tokens.access_token) !== "" || str(tokens.refresh_token) !== "" || apiKey !== "");
  return { accountId, email: str(claims.email), plan: capitalize(str(openai.chatgpt_plan_type)), signedIn };
}

// Grok keeps one login per issuer in auth.json.
function grokIdentity(home: string): Identity {
  const text = readText(join(home, "auth.json"));
  if (text === null) return NOBODY;
  const auth = obj(readJson(join(home, "auth.json")));
  const login = obj(Object.values(auth).find((v) => Object.keys(obj(v)).length > 0));
  const email = str(login.email);
  const accountId =
    str(login.account_id) || str(login.user_id) || str(login.sub) || email || (text.trim() ? `grok-${shortHash(text)}` : "");
  return { accountId, email, plan: "", signedIn: accountId !== "" };
}

export function identity(d: Pick<AccountsDeps, "home">, p: AccountProvider, home: string): Identity {
  if (p === "claude") return claudeIdentity(d, home);
  if (p === "codex") return codexIdentity(home);
  return grokIdentity(home);
}

// ── registry ────────────────────────────────────────────────────────────────

function primaryEntry(d: Pick<AccountsDeps, "home">, p: AccountProvider): Account {
  const found = identity(d, p, primaryHome(d, p));
  return { id: "main", label: "Main", primary: true, home: "", accountId: found.accountId, email: found.email, plan: found.plan };
}

function slug(label: string): string {
  return label
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 32)
    .replace(/-+$/, "");
}

const ID_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

function normalize(d: Pick<AccountsDeps, "env" | "home">, p: AccountProvider, raw: unknown): Registry {
  const r = obj(raw);
  const accounts: Account[] = [];
  const ids = new Set<string>();
  for (const entry of Array.isArray(r.accounts) ? r.accounts : []) {
    const e = obj(entry);
    const id = str(e.id);
    const primary = e.primary === true;
    const home = primary ? "" : str(e.home);
    if (!ID_RE.test(id) || ids.has(id)) continue;
    if (primary && accounts.some((a) => a.primary)) continue;
    if (!primary && !ownedHome(d, p, home)) continue;
    ids.add(id);
    accounts.push({
      id,
      label: str(e.label) || id,
      primary,
      home,
      accountId: str(e.accountId),
      email: str(e.email),
      plan: str(e.plan),
    });
  }
  if (!accounts.some((a) => a.primary)) {
    const main = primaryEntry(d, p);
    if (ids.has(main.id)) main.id = uniqueIdIn(accounts, "main");
    accounts.unshift(main);
  }
  const threshold = Math.round(Number(r.threshold));
  const registry: Registry = {
    schemaVersion: REGISTRY_SCHEMA_VERSION,
    active: str(r.active),
    switch: r.switch === "auto" ? "auto" : "manual",
    threshold: Number.isFinite(threshold) ? Math.max(50, Math.min(100, threshold)) : DEFAULT_THRESHOLD,
    alert: str(r.alert),
    accounts,
  };
  if (!findAccount(registry, registry.active)) registry.active = accounts[0]!.id;
  return registry;
}

export function loadRegistry(d: Pick<AccountsDeps, "env" | "home">, p: AccountProvider): Registry {
  return normalize(d, p, readJson(registryPath(d, p)));
}

function saveRegistry(d: Pick<AccountsDeps, "env" | "home">, p: AccountProvider, r: Registry): void {
  const root = accountsRoot(d);
  mkdirSync(root, { recursive: true, mode: 0o700 });
  chmodSync(root, 0o700);
  writePrivateFile(registryPath(d, p), JSON.stringify(r, null, 2) + "\n");
}

// One read-modify-write at a time per provider, so the panel, the autoswitch
// after a usage refresh and a typed command cannot drop each other's edits.
function withLock<T>(d: Pick<AccountsDeps, "env" | "home">, p: AccountProvider, fn: () => T): T {
  const root = accountsRoot(d);
  mkdirSync(root, { recursive: true, mode: 0o700 });
  const lock = join(root, `.${p}.lock`);
  const deadline = Date.now() + LOCK_WAIT_MS;
  for (;;) {
    try {
      closeSync(openSync(lock, "wx", 0o600));
      break;
    } catch (e) {
      if ((e as NodeJS.ErrnoException).code !== "EEXIST") throw e;
      try {
        if (Date.now() - statSync(lock).mtimeMs > LOCK_STALE_MS) rmSync(lock, { force: true });
      } catch {
        // released meanwhile
      }
      if (Date.now() > deadline) throw new AccountError("the account registry is busy; try again");
      Bun.sleepSync(20);
    }
  }
  try {
    return fn();
  } finally {
    rmSync(lock, { force: true });
  }
}

export function updateRegistry<T>(
  d: Pick<AccountsDeps, "env" | "home">,
  p: AccountProvider,
  fn: (r: Registry) => T,
): T {
  return withLock(d, p, () => {
    const r = loadRegistry(d, p);
    const out = fn(r);
    saveRegistry(d, p, r);
    return out;
  });
}

export function findAccount(r: Registry, target: string): Account | undefined {
  return r.accounts.find((a) => a.id === target) ?? (target === "primary" ? r.accounts.find((a) => a.primary) : undefined);
}

export function activeAccount(r: Registry): Account {
  return findAccount(r, r.active) ?? r.accounts[0]!;
}

function mustFind(r: Registry, p: AccountProvider, target: string): Account {
  const a = findAccount(r, target);
  if (!a) throw new AccountError(`no ${PROVIDER_SPECS[p].name} account named ${target}`);
  return a;
}

// Who each home is signed in as now: a login run by hand changes it.
function refreshIdentities(d: Pick<AccountsDeps, "env" | "home">, p: AccountProvider, r: Registry): Map<string, boolean> {
  const signedIn = new Map<string, boolean>();
  for (const a of r.accounts) {
    const found = identity(d, p, accountHome(d, p, a));
    a.accountId = found.accountId;
    if (found.email) a.email = found.email;
    if (found.plan) a.plan = found.plan;
    signedIn.set(a.id, found.signedIn);
  }
  return signedIn;
}

function uniqueIdIn(accounts: Account[], base: string, keep?: Account, taken?: (id: string) => boolean): string {
  let id = base;
  for (let n = 2; ; n++) {
    const other = accounts.find((a) => a.id === id);
    if (!RESERVED_IDS.has(id) && (!other || other === keep) && !(taken?.(id) ?? false)) return id;
    id = `${base}-${n}`;
  }
}

// An id never reuses a home left on disk by an account renamed since.
function uniqueId(d: Pick<AccountsDeps, "env" | "home">, p: AccountProvider, r: Registry, label: string): string {
  return uniqueIdIn(r.accounts, slug(label) || "account", undefined, (id) => exists(join(accountsRoot(d), p, id)));
}

export function summarizeRegistry(
  d: Pick<AccountsDeps, "env" | "home">,
  p: AccountProvider,
  r: Registry,
): ProviderAccounts {
  const signedIn = refreshIdentities(d, p, r);
  return {
    provider: p,
    name: PROVIDER_SPECS[p].name,
    active: r.active,
    switch: r.switch,
    threshold: r.threshold,
    accounts: r.accounts.map((a) => ({
      id: a.id,
      label: a.label,
      email: a.email,
      plan: a.plan,
      primary: a.primary,
      active: a.id === r.active,
      signedIn: signedIn.get(a.id) ?? false,
      home: accountHome(d, p, a),
    })),
  };
}

export function listAccounts(
  d: Pick<AccountsDeps, "env" | "home">,
  providers: readonly AccountProvider[] = ACCOUNT_PROVIDERS,
): ProviderAccounts[] {
  return providers.map((p) => summarizeRegistry(d, p, loadRegistry(d, p)));
}

// ── homes ───────────────────────────────────────────────────────────────────

// Links everything but the login back to the primary home. Repeating it is
// safe: an existing link or a file the account wrote for itself stays.
export function linkShared(d: Pick<AccountsDeps, "home">, p: AccountProvider, home: string): void {
  const spec = PROVIDER_SPECS[p];
  const primary = primaryHome(d, p);
  mkdirSync(home, { recursive: true, mode: 0o700 });
  chmodSync(home, 0o700);
  mkdirSync(primary, { recursive: true, mode: 0o700 });
  for (const name of spec.sharedDirs) {
    const shared = join(primary, name);
    // A dangling link is the person's own setup (a dotfiles link not synced
    // yet): leave it for its target to appear.
    if (exists(shared) && !existsSync(shared)) continue;
    mkdirSync(shared, { recursive: true });
  }
  for (const name of [...spec.sharedDirs, ...spec.sharedFiles]) {
    const target = join(home, name);
    if (!exists(target)) symlinkSync(join(primary, name), target);
  }
}

function carrySettings(d: Pick<AccountsDeps, "home">, p: AccountProvider, home: string): void {
  const keys = PROVIDER_SPECS[p].carriedKeys;
  if (keys.length === 0) return;
  const source = obj(readJson(claudeAccountFile(d, primaryHome(d, p))));
  const path = claudeAccountFile(d, home);
  const data = obj(readJson(path));
  for (const key of keys) if (key in source && !(key in data)) data[key] = source[key];
  writePrivateFile(path, JSON.stringify(data, null, 2));
}

function pendingRoot(d: Pick<AccountsDeps, "env" | "home">, p: AccountProvider): string {
  return join(accountsRoot(d), p, ".pending");
}

// A login in progress signs in to a scratch home beside the real ones.
export function beginLogin(d: Pick<AccountsDeps, "env" | "home">, p: AccountProvider): string {
  const pending = pendingRoot(d, p);
  mkdirSync(pending, { recursive: true, mode: 0o700 });
  chmodSync(join(accountsRoot(d), p), 0o700);
  const home = mkdtempSync(join(pending, "login-"));
  try {
    linkShared(d, p, home);
  } catch (e) {
    rmSync(home, { recursive: true, force: true });
    throw e;
  }
  return home;
}

function isPending(d: Pick<AccountsDeps, "env" | "home">, p: AccountProvider, home: string): boolean {
  return dirname(resolve(home)) === pendingRoot(d, p);
}

export function discardLogin(d: Pick<AccountsDeps, "env" | "home">, p: AccountProvider, home: string): void {
  if (isPending(d, p, home)) rmSync(home, { recursive: true, force: true });
}

export function registerLogin(
  d: Pick<AccountsDeps, "env" | "home">,
  p: AccountProvider,
  label: string,
  pending: string,
): Account {
  if (!isPending(d, p, pending)) throw new AccountError(`${pending} is not a pending ${PROVIDER_SPECS[p].name} login`);
  const found = identity(d, p, pending);
  if (!found.signedIn) {
    discardLogin(d, p, pending);
    throw new AccountError("the sign-in did not finish, so no account was added");
  }
  return updateRegistry(d, p, (r) => {
    refreshIdentities(d, p, r);
    const same = r.accounts.find((a) => a.accountId === found.accountId);
    if (same) {
      discardLogin(d, p, pending);
      const who = found.email ? `${same.label} (${found.email})` : same.label;
      throw new AccountError(`that is ${who}, already added; sign in as the other account in a private window`);
    }
    const name = label.trim() || found.email.split("@")[0] || "Account";
    const id = uniqueId(d, p, r, name);
    carrySettings(d, p, pending);
    const home = join(accountsRoot(d), p, id);
    renameSync(pending, home);
    const entry: Account = { id, label: name, primary: false, home, ...pick(found) };
    r.accounts.push(entry);
    return entry;
  });
}

function pick(found: Identity): Pick<Account, "accountId" | "email" | "plan"> {
  return { accountId: found.accountId, email: found.email, plan: found.plan };
}

export function useAccount(
  d: Pick<AccountsDeps, "env" | "home">,
  p: AccountProvider,
  target: string,
): { previous: Account; active: Account } {
  return updateRegistry(d, p, (r) => {
    const previous = activeAccount(r);
    let id = target;
    if (target === "next") {
      const i = r.accounts.indexOf(previous);
      id = r.accounts[(i + 1) % r.accounts.length]!.id;
    }
    const account = mustFind(r, p, id);
    r.active = account.id;
    r.alert = "";
    if (!account.primary) linkShared(d, p, account.home);
    return { previous: { ...previous }, active: { ...account } };
  });
}

// Whether a running process was started with this home selected. Removing
// it would pull the login out from under that session.
export function homeInUse(d: AccountsDeps, p: AccountProvider, home: string): boolean {
  const wanted = `${PROVIDER_SPECS[p].homeEnv}=`;
  const target = resolve(home);
  let pids: string[];
  try {
    pids = readdirSync(d.procRoot).filter((n) => /^\d+$/.test(n));
  } catch {
    return false;
  }
  for (const pid of pids) {
    let environ: string;
    try {
      environ = readFileSync(join(d.procRoot, pid, "environ"), "latin1");
    } catch {
      continue;
    }
    for (const entry of environ.split("\0")) {
      if (entry.startsWith(wanted) && resolve(entry.slice(wanted.length)) === target) return true;
    }
  }
  return false;
}

export function removeAccount(d: AccountsDeps, p: AccountProvider, target: string): Account {
  return updateRegistry(d, p, (r) => {
    const account = mustFind(r, p, target);
    if (account.primary) {
      throw new AccountError(`${account.label} is the login in ${primaryHome(d, p)}; it cannot be removed here`);
    }
    if (homeInUse(d, p, account.home)) {
      throw new AccountError(`a running ${PROVIDER_SPECS[p].name} session uses ${account.label}; quit it first`);
    }
    // rm removes the shared links without following them.
    if (ownedHome(d, p, account.home)) rmSync(account.home, { recursive: true, force: true });
    r.accounts = r.accounts.filter((a) => a !== account);
    if (r.active === account.id) r.active = r.accounts[0]!.id;
    r.alert = "";
    return { ...account };
  });
}

// The home stays where it is: sessions already running hold that path.
export function renameAccount(
  d: Pick<AccountsDeps, "env" | "home">,
  p: AccountProvider,
  target: string,
  label: string,
): Account {
  const name = label.trim();
  if (name === "") throw new AccountError("give the account a name");
  return updateRegistry(d, p, (r) => {
    const account = mustFind(r, p, target);
    const id = uniqueIdIn(r.accounts, slug(name) || "account", account);
    if (r.active === account.id) r.active = id;
    account.id = id;
    account.label = name;
    r.alert = "";
    return { ...account };
  });
}

export function setSwitchMode(
  d: Pick<AccountsDeps, "env" | "home">,
  p: AccountProvider,
  mode: string,
  threshold?: string,
): Registry {
  if (mode !== "manual" && mode !== "auto") throw new AccountError("the switch mode is manual or auto");
  let percent: number | undefined;
  if (threshold !== undefined) {
    percent = Number(threshold);
    if (!Number.isInteger(percent) || percent < 50 || percent > 100) {
      throw new AccountError("the threshold is a whole percentage from 50 to 100");
    }
  }
  return updateRegistry(d, p, (r) => {
    r.switch = mode;
    if (percent !== undefined) r.threshold = percent;
    r.alert = "";
    return { ...r };
  });
}

// ── switching policy ────────────────────────────────────────────────────────

function windowOpen(limit: UsageLimit, now: number): boolean {
  const t = Date.parse(limit.resetsAt);
  return Number.isNaN(t) || t > now;
}

// How spent an account is in percent: its fullest window that has not reset.
// A window whose reset has passed counts as empty. null when nothing is known.
export function peak(limits: UsageLimit[] | undefined, now: number): number | null {
  if (!limits || limits.length === 0) return null;
  const open = limits.filter((l) => windowOpen(l, now)).map((l) => l.percent * 100);
  return open.length > 0 ? Math.max(...open) : 0;
}

function nextReset(limits: UsageLimit[] | undefined, now: number): number {
  const times = (limits ?? []).map((l) => Date.parse(l.resetsAt)).filter((t) => !Number.isNaN(t) && t > now);
  return times.length > 0 ? Math.min(...times) : Number.POSITIVE_INFINITY;
}

export type Decision =
  | { action: "clear" }
  | { action: "switch" | "notify"; alert: string; from: Account; to: Account; fromPeak: number; toPeak: number }
  | { action: "exhausted"; alert: string; from: Account; fromPeak: number };

// The whole policy, without I/O. Only the active account crossing the
// threshold starts anything, so auto mode never flaps back to an account that
// just reset. `alert` remembers the last thing said, so it is said once.
export function decide(
  r: Registry,
  usage: Record<string, UsageLimit[] | undefined>,
  now: number,
): Decision | null {
  const current = activeAccount(r);
  const currentPeak = peak(usage[current.id], now);
  if (currentPeak === null || currentPeak < r.threshold) return r.alert ? { action: "clear" } : null;
  const candidates = r.accounts
    .filter((a) => a !== current)
    .map((a) => ({ a, level: peak(usage[a.id], now), reset: nextReset(usage[a.id], now) }))
    .filter((c): c is { a: Account; level: number; reset: number } => c.level !== null && c.level < r.threshold)
    .sort((x, y) => {
      const near = Number(x.level >= r.threshold - NEAR_MARGIN) - Number(y.level >= r.threshold - NEAR_MARGIN);
      return near || x.level - y.level || x.reset - y.reset;
    });
  const best = candidates[0];
  if (best) {
    const action = r.switch === "auto" ? "switch" : "notify";
    const alert = `${action}:${current.id}:${best.a.id}`;
    if (r.alert === alert) return null;
    return { action, alert, from: current, to: best.a, fromPeak: currentPeak, toPeak: best.level };
  }
  const alert = `exhausted:${current.id}`;
  if (r.alert === alert || r.accounts.length < 2) return null;
  // Only when every account is known to be over; one that could not be
  // checked might have room.
  if (r.accounts.some((a) => peak(usage[a.id], now) === null)) return null;
  return { action: "exhausted", alert, from: current, fromPeak: currentPeak };
}

export interface SwitchOffer {
  alert: string;
  from: { id: string; label: string };
  to: { id: string; label: string };
  fromPercent: number;
  toPercent: number;
}

export interface AutoswitchResult {
  switched: boolean;
  offer?: SwitchOffer;
  message?: { title: string; body: string };
}

// The manual-mode offer stays on show until it is acted on or cleared, so
// the shell can raise it whenever it first reads the record.
function standingOffer(r: Registry, usage: Record<string, UsageLimit[] | undefined>, now: number): SwitchOffer | undefined {
  const [kind, fromId, toId] = r.alert.split(":");
  if (kind !== "notify" || !fromId || !toId) return undefined;
  const from = findAccount(r, fromId);
  const to = findAccount(r, toId);
  if (!from || !to || r.active !== from.id) return undefined;
  return {
    alert: r.alert,
    from: { id: from.id, label: from.label },
    to: { id: to.id, label: to.label },
    fromPercent: Math.round(peak(usage[from.id], now) ?? 0),
    toPercent: Math.round(peak(usage[to.id], now) ?? 0),
  };
}

export function applyAutoswitch(
  d: Pick<AccountsDeps, "env" | "home">,
  p: AccountProvider,
  usage: Record<string, UsageLimit[] | undefined>,
  now: number,
): AutoswitchResult {
  const name = PROVIDER_SPECS[p].name;
  return updateRegistry(d, p, (r) => {
    if (r.accounts.length < 2) return { switched: false };
    const decision = decide(r, usage, now);
    if (decision === null) return { switched: false, offer: standingOffer(r, usage, now) };
    if (decision.action === "clear") {
      r.alert = "";
      return { switched: false };
    }
    r.alert = decision.alert;
    const headline = `${decision.from.label} is at ${Math.round(decision.fromPeak)}% of a ${name} limit`;
    if (decision.action === "exhausted") {
      return { switched: false, message: { title: `All ${name} accounts are over ${r.threshold}%`, body: `Staying on ${decision.from.label}.` } };
    }
    if (decision.action === "switch") {
      r.active = decision.to.id;
      if (!decision.to.primary) linkShared(d, p, decision.to.home);
      const body = `New ${name} sessions now use ${decision.to.label} (${Math.round(decision.toPeak)}%). Running sessions stay on ${decision.from.label}.`;
      return { switched: true, message: { title: headline, body } };
    }
    return { switched: false, offer: standingOffer(r, usage, now) };
  });
}

// ── transfer ────────────────────────────────────────────────────────────────

export interface TransferAccount {
  id: string;
  label: string;
  primary: boolean;
  accountId: string;
  files: Record<string, string>;
}

export interface TransferBundle {
  version: 1;
  providers: Partial<Record<AccountProvider, TransferAccount[]>>;
}

function loginFiles(d: Pick<AccountsDeps, "home">, p: AccountProvider, home: string): Record<string, string> {
  if (p === "claude") {
    const oauthAccount = obj(readJson(claudeAccountFile(d, home))).oauthAccount;
    const credentials = readText(join(home, ".credentials.json"));
    if (oauthAccount === undefined || credentials === null) return {};
    return { ".claude.json": JSON.stringify({ oauthAccount }), ".credentials.json": credentials };
  }
  const files: Record<string, string> = {};
  for (const name of PROVIDER_SPECS[p].credentialFiles) {
    const text = readText(join(home, name));
    if (text !== null) files[name] = text;
  }
  return files["auth.json"] !== undefined ? files : {};
}

// Only the signed-in accounts' credential files, in memory.
export function exportBundle(
  d: Pick<AccountsDeps, "env" | "home">,
  providers: readonly AccountProvider[] = ACCOUNT_PROVIDERS,
): TransferBundle {
  const bundle: TransferBundle = { version: 1, providers: {} };
  for (const p of providers) {
    const r = loadRegistry(d, p);
    const entries: TransferAccount[] = [];
    for (const a of r.accounts) {
      const home = accountHome(d, p, a);
      const found = identity(d, p, home);
      const files = loginFiles(d, p, home);
      if (found.signedIn && Object.keys(files).length > 0) {
        entries.push({ id: a.id, label: a.label, primary: a.primary, accountId: found.accountId, files });
      }
    }
    if (entries.length > 0) bundle.providers[p] = entries;
  }
  return bundle;
}

export function parseBundle(raw: unknown): TransferBundle {
  const b = obj(raw);
  if (b.version !== 1) throw new AccountError("unsupported account transfer stream");
  const providers: TransferBundle["providers"] = {};
  for (const [p, list] of Object.entries(obj(b.providers))) {
    if (!isAccountProvider(p) || !Array.isArray(list) || list.length === 0) {
      throw new AccountError("invalid account transfer provider");
    }
    const allowed = new Set(PROVIDER_SPECS[p].credentialFiles);
    const seen = new Set<string>();
    providers[p] = list.map((entry): TransferAccount => {
      const e = obj(entry);
      const files = obj(e.files);
      const names = Object.keys(files);
      const ok =
        ID_RE.test(str(e.id)) &&
        str(e.label).trim() !== "" &&
        str(e.accountId) !== "" &&
        typeof e.primary === "boolean" &&
        !seen.has(str(e.accountId)) &&
        names.length > 0 &&
        names.every((n) => allowed.has(n) && typeof files[n] === "string");
      if (!ok) throw new AccountError("invalid account in the transfer stream");
      seen.add(str(e.accountId));
      return {
        id: str(e.id),
        label: str(e.label).trim(),
        primary: e.primary as boolean,
        accountId: str(e.accountId),
        files: files as Record<string, string>,
      };
    });
  }
  return { version: 1, providers };
}

function writeCredential(d: Pick<AccountsDeps, "home">, p: AccountProvider, home: string, name: string, text: string): void {
  const path = credentialPath(d, p, home, name);
  if (p === "claude" && name === ".claude.json") {
    // Keep local onboarding, folder trust and MCP settings; take the login.
    const merged = { ...obj(readJson(path)), ...obj(JSON.parse(text)) };
    writePrivateFile(path, JSON.stringify(merged, null, 2));
    return;
  }
  writePrivateFile(path, text);
}

interface Placement {
  entry: TransferAccount;
  account?: Account;
}

function planImport(
  d: Pick<AccountsDeps, "env" | "home">,
  p: AccountProvider,
  r: Registry,
  entries: TransferAccount[],
): { placements: Placement[]; conflicts: string[] } {
  const signedIn = refreshIdentities(d, p, r);
  const conflicts: string[] = [];
  const placements = entries.map((entry) => {
    const account = r.accounts.find((a) => a.accountId === entry.accountId);
    if (account && signedIn.get(account.id)) conflicts.push(`${PROVIDER_SPECS[p].name} ${account.label}`);
    return { entry, account };
  });
  return { placements, conflicts };
}

// Receives a bundle from `marchyo agent account copy`. An account already
// signed in here is replaced only with `replace`; otherwise nothing is
// written and TransferConflict names them.
export function importBundle(
  d: Pick<AccountsDeps, "env" | "home">,
  raw: unknown,
  opts: { replace: boolean },
): string[] {
  const bundle = parseBundle(raw);
  const providers = Object.keys(bundle.providers) as AccountProvider[];
  if (!opts.replace) {
    const conflicts = providers.flatMap(
      (p) => planImport(d, p, loadRegistry(d, p), bundle.providers[p]!).conflicts,
    );
    if (conflicts.length > 0) throw new TransferConflict(conflicts);
  }
  const lines: string[] = [];
  for (const p of providers) {
    updateRegistry(d, p, (r) => {
      const { placements } = planImport(d, p, r, bundle.providers[p]!);
      const primarySignedIn = identity(d, p, primaryHome(d, p)).signedIn;
      for (const { entry, account: found } of placements) {
        let account = found;
        if (!account && entry.primary && !primarySignedIn) account = r.accounts.find((a) => a.primary);
        if (!account) {
          const id = uniqueId(d, p, r, entry.label);
          const home = join(accountsRoot(d), p, id);
          account = { id, label: entry.label, primary: false, home, accountId: "", email: "", plan: "" };
          r.accounts.push(account);
        }
        const home = accountHome(d, p, account);
        mkdirSync(home, { recursive: true, mode: 0o700 });
        chmodSync(home, 0o700);
        if (!account.primary) linkShared(d, p, home);
        for (const [name, text] of Object.entries(entry.files)) writeCredential(d, p, home, name, text);
        if (!account.primary) carrySettings(d, p, home);
        const now = identity(d, p, home);
        Object.assign(account, pick(now));
        const who = now.email ? ` (${now.email})` : "";
        lines.push(`${PROVIDER_SPECS[p].name}: copied ${account.label}${who}`);
      }
      r.alert = "";
    });
  }
  return lines;
}

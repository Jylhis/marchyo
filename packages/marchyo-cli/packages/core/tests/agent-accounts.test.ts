import { expect, test } from "bun:test";
import {
  existsSync,
  lstatSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readlinkSync,
  readdirSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  type AccountsDeps,
  AccountError,
  PROVIDER_SPECS,
  type Registry,
  TransferConflict,
  accountsRoot,
  applyAutoswitch,
  beginLogin,
  decide,
  exportBundle,
  importBundle,
  listAccounts,
  loadRegistry,
  registerLogin,
  registryPath,
  removeAccount,
  renameAccount,
  setSwitchMode,
  useAccount,
} from "../src/agent-accounts.ts";
import type { UsageLimit } from "../src/agent-usage.ts";

const NOW = Date.parse("2026-11-05T12:00:00Z");
const SOON = "2026-11-05T15:00:00.000Z";

function tempDeps(): AccountsDeps {
  const home = mkdtempSync(join(tmpdir(), "marchyo-agent-accounts-"));
  mkdirSync(join(home, "proc"));
  return { env: { XDG_STATE_HOME: join(home, "state") }, home, procRoot: join(home, "proc") };
}

const secretFor = (who: string) => `sk-ant-oat01-FAKE-${who}-SECRET`;

// What `claude auth login` leaves behind in a home.
function claudeLogin(d: AccountsDeps, home: string, who: string, primary = false): void {
  mkdirSync(home, { recursive: true });
  writeFileSync(
    join(home, ".credentials.json"),
    JSON.stringify({ claudeAiOauth: { accessToken: secretFor(who), refreshToken: `r-${secretFor(who)}`, subscriptionType: "pro" } }),
  );
  const accountFile = primary ? join(d.home, ".claude.json") : join(home, ".claude.json");
  const prev = existsSync(accountFile) ? JSON.parse(readFileSync(accountFile, "utf8")) : {};
  writeFileSync(accountFile, JSON.stringify({ ...prev, oauthAccount: { accountUuid: `uuid-${who}`, emailAddress: `${who}@example.com` } }));
}

function withPrimary(): AccountsDeps {
  const d = tempDeps();
  writeFileSync(join(d.home, ".claude.json"), JSON.stringify({ theme: "dark", mcpServers: { x: {} } }));
  claudeLogin(d, join(d.home, ".claude"), "main", true);
  return d;
}

function addClaude(d: AccountsDeps, who: string, label = who): string {
  const pending = beginLogin(d, "claude");
  claudeLogin(d, pending, who);
  return registerLogin(d, "claude", label, pending).id;
}

const mode = (path: string) => statSync(path).mode & 0o777;

test("an added account links everything but its credentials to the primary home", () => {
  const d = withPrimary();
  const id = addClaude(d, "work", "Work");
  const home = join(accountsRoot(d), "claude", id);
  const spec = PROVIDER_SPECS.claude;
  for (const name of [...spec.sharedDirs, ...spec.sharedFiles]) {
    expect(lstatSync(join(home, name)).isSymbolicLink()).toBe(true);
    expect(readlinkSync(join(home, name))).toBe(join(d.home, ".claude", name));
  }
  for (const name of spec.credentialFiles) expect(lstatSync(join(home, name)).isSymbolicLink()).toBe(false);
  expect(mode(home)).toBe(0o700);
  // History written as the added account lands in the shared history.
  writeFileSync(join(home, "projects", "session.jsonl"), "{}\n");
  writeFileSync(join(home, "history.jsonl"), "{}\n");
  expect(existsSync(join(d.home, ".claude", "projects", "session.jsonl"))).toBe(true);
  expect(existsSync(join(d.home, ".claude", "history.jsonl"))).toBe(true);
  // Settings carried from the primary account file; the login is its own.
  const own = JSON.parse(readFileSync(join(home, ".claude.json"), "utf8"));
  expect(own.theme).toBe("dark");
  expect(own.oauthAccount.accountUuid).toBe("uuid-work");
  expect(readdirSync(join(accountsRoot(d), "claude", ".pending"))).toEqual([]);
});

test("credentials stay separate per account; the registry holds none", () => {
  const d = withPrimary();
  addClaude(d, "work");
  const primary = readFileSync(join(d.home, ".claude", ".credentials.json"), "utf8");
  expect(primary).toContain(secretFor("main"));
  expect(primary).not.toContain(secretFor("work"));
  const registry = readFileSync(registryPath(d, "claude"), "utf8");
  for (const who of ["main", "work"]) expect(registry.includes(secretFor(who))).toBe(false);
  expect(mode(registryPath(d, "claude"))).toBe(0o600);
  const listed = JSON.stringify(listAccounts(d));
  expect(listed.includes(secretFor("work"))).toBe(false);
  const [claude] = listAccounts(d, ["claude"]);
  expect(claude!.accounts.map((a) => [a.id, a.email, a.signedIn, a.active])).toEqual([
    ["main", "main@example.com", true, true],
    ["work", "work@example.com", true, false],
  ]);
});

test("the same login twice, or an unfinished one, adds nothing", () => {
  const d = withPrimary();
  addClaude(d, "work");
  expect(() => addClaude(d, "work", "Again")).toThrow(AccountError);
  const pending = beginLogin(d, "claude");
  expect(() => registerLogin(d, "claude", "Half", pending)).toThrow("did not finish");
  expect(existsSync(pending)).toBe(false);
  expect(loadRegistry(d, "claude").accounts).toHaveLength(2);
});

test("use, rename and remove; the primary and a home in use stay", () => {
  const d = withPrimary();
  const id = addClaude(d, "work", "Work");
  expect(useAccount(d, "claude", "next").active.id).toBe("work");
  expect(useAccount(d, "claude", "next").active.id).toBe("main");
  useAccount(d, "claude", id);
  const renamed = renameAccount(d, "claude", "work", "Side project");
  expect(renamed.id).toBe("side-project");
  expect(loadRegistry(d, "claude").active).toBe("side-project");
  expect(() => removeAccount(d, "claude", "main")).toThrow("cannot be removed");
  const home = renamed.home;
  mkdirSync(join(d.procRoot, "4242"));
  writeFileSync(join(d.procRoot, "4242", "environ"), `PATH=/bin\0CLAUDE_CONFIG_DIR=${home}\0`);
  expect(() => removeAccount(d, "claude", "side-project")).toThrow("running");
  writeFileSync(join(d.procRoot, "4242", "environ"), "PATH=/bin\0");
  removeAccount(d, "claude", "side-project");
  expect(existsSync(home)).toBe(false);
  // The shared files behind the links survive.
  expect(existsSync(join(d.home, ".claude", "projects"))).toBe(true);
  expect(loadRegistry(d, "claude").active).toBe("main");
});

test("a registry entry pointing outside the accounts directory is dropped", () => {
  const d = withPrimary();
  mkdirSync(accountsRoot(d), { recursive: true });
  writeFileSync(
    registryPath(d, "claude"),
    JSON.stringify({ active: "evil", accounts: [{ id: "evil", label: "Evil", home: "/etc" }] }),
  );
  const r = loadRegistry(d, "claude");
  expect(r.accounts.map((a) => a.id)).toEqual(["main"]);
  expect(r.active).toBe("main");
});

test("mode and threshold are validated", () => {
  const d = withPrimary();
  expect(setSwitchMode(d, "claude", "auto", "90").threshold).toBe(90);
  expect(() => setSwitchMode(d, "claude", "sometimes")).toThrow(AccountError);
  expect(() => setSwitchMode(d, "claude", "auto", "20")).toThrow(AccountError);
});

// ── policy ──────────────────────────────────────────────────────────────────

const lim = (percent: number, resetsAt = SOON): UsageLimit[] => [{ label: "Session", percent, resetsAt }];

function registry(over: Partial<Registry> = {}): Registry {
  const acct = (id: string, primary = false) => ({ id, label: id, primary, home: "", accountId: id, email: "", plan: "" });
  return {
    schemaVersion: 1,
    active: "main",
    switch: "auto",
    threshold: 90,
    alert: "",
    accounts: [acct("main", true), acct("a"), acct("b"), acct("c")],
    ...over,
  };
}

test("auto picks the account with the most headroom once the active one crosses", () => {
  const usage = { main: lim(0.92), a: lim(0.5), b: lim(0.2), c: lim(0.95) };
  const d = decide(registry(), usage, NOW);
  expect(d).toMatchObject({ action: "switch", to: { id: "b" } });
  expect(decide(registry(), { ...usage, main: lim(0.8) }, NOW)).toBeNull();
  // The same alert is not said twice.
  expect(decide(registry({ alert: "switch:main:b" }), usage, NOW)).toBeNull();
  // Manual mode offers instead of switching.
  expect(decide(registry({ switch: "manual" }), usage, NOW)).toMatchObject({ action: "notify", to: { id: "b" } });
});

test("a reset window counts as empty; unknown accounts are no candidates", () => {
  const past = "2026-11-05T11:00:00.000Z";
  const usage = { main: lim(0.99), a: lim(0.99, past), b: undefined, c: lim(0.97) };
  expect(decide(registry(), usage, NOW)).toMatchObject({ action: "switch", to: { id: "a" } });
  expect(decide(registry(), { main: lim(0.99), a: lim(0.97), b: undefined, c: lim(0.98) }, NOW)).toBeNull();
  expect(decide(registry(), { main: lim(0.99), a: lim(0.97), b: lim(0.98), c: lim(0.98) }, NOW)).toMatchObject({
    action: "exhausted",
  });
});

test("applyAutoswitch moves the active account in auto mode and keeps a manual offer", () => {
  const d = withPrimary();
  addClaude(d, "work", "Work");
  setSwitchMode(d, "claude", "auto", "90");
  const auto = applyAutoswitch(d, "claude", { main: lim(0.95), work: lim(0.1) }, NOW);
  expect(auto.switched).toBe(true);
  expect(auto.message?.body).toContain("Work");
  expect(loadRegistry(d, "claude").active).toBe("work");

  setSwitchMode(d, "claude", "manual");
  const first = applyAutoswitch(d, "claude", { main: lim(0.1), work: lim(0.96) }, NOW);
  expect(first.offer).toMatchObject({ from: { id: "work" }, to: { id: "main" }, fromPercent: 96 });
  expect(loadRegistry(d, "claude").active).toBe("work");
  // Still on show at the next refresh, gone after a switch.
  expect(applyAutoswitch(d, "claude", { main: lim(0.1), work: lim(0.96) }, NOW).offer?.to.id).toBe("main");
  useAccount(d, "claude", "main");
  expect(applyAutoswitch(d, "claude", { main: lim(0.1), work: lim(0.96) }, NOW).offer).toBeUndefined();
});

// ── transfer ────────────────────────────────────────────────────────────────

test("copy: credential files only, 0600 files in 0700 dirs, overwrite needs --replace", () => {
  const src = withPrimary();
  addClaude(src, "work", "Work");
  const codexHome = join(src.home, ".codex");
  mkdirSync(codexHome);
  writeFileSync(join(codexHome, "auth.json"), JSON.stringify({ tokens: { account_id: "acct-1", access_token: "FAKE-CODEX-SECRET" } }));
  writeFileSync(join(src.home, ".claude", "settings.json"), "{}");
  const bundle = JSON.parse(JSON.stringify(exportBundle(src)));
  expect(Object.keys(bundle.providers).sort()).toEqual(["claude", "codex"]);
  for (const entry of bundle.providers.claude) {
    expect(Object.keys(entry.files).sort()).toEqual([".claude.json", ".credentials.json"]);
    expect(Object.keys(JSON.parse(entry.files[".claude.json"]))).toEqual(["oauthAccount"]);
  }

  const dst = tempDeps();
  const lines = importBundle(dst, bundle, { replace: false });
  expect(lines).toHaveLength(3);
  const work = join(accountsRoot(dst), "claude", "work");
  for (const path of [join(work, ".credentials.json"), join(work, ".claude.json"), join(dst.home, ".claude", ".credentials.json"), join(dst.home, ".codex", "auth.json")]) {
    expect(mode(path)).toBe(0o600);
  }
  for (const dir of [work, join(dst.home, ".claude"), join(dst.home, ".codex")]) expect(mode(dir)).toBe(0o700);
  expect(lstatSync(join(work, "projects")).isSymbolicLink()).toBe(true);
  expect(readFileSync(join(work, ".credentials.json"), "utf8")).toContain(secretFor("work"));
  expect(existsSync(join(dst.home, ".claude", "settings.json"))).toBe(false);
  expect(lines.join("\n").includes(secretFor("work"))).toBe(false);

  // A second copy would replace those sign-ins: refused, nothing written.
  writeFileSync(join(work, ".credentials.json"), JSON.stringify({ claudeAiOauth: { accessToken: "LOCAL" } }));
  expect(() => importBundle(dst, bundle, { replace: false })).toThrow(TransferConflict);
  expect(readFileSync(join(work, ".credentials.json"), "utf8")).toContain("LOCAL");
  importBundle(dst, bundle, { replace: true });
  expect(readFileSync(join(work, ".credentials.json"), "utf8")).toContain(secretFor("work"));
  expect(loadRegistry(dst, "claude").accounts).toHaveLength(2);
});

test("an import with a foreign file name or a bad id is refused", () => {
  const dst = tempDeps();
  const entry = { id: "x", label: "X", primary: false, accountId: "a", files: { "auth.json": "{}" } };
  expect(() => importBundle(dst, { version: 1, providers: { codex: [{ ...entry, files: { "../evil": "x" } }] } }, { replace: true })).toThrow(AccountError);
  expect(() => importBundle(dst, { version: 1, providers: { codex: [{ ...entry, id: "../x" }] } }, { replace: true })).toThrow(AccountError);
  expect(() => importBundle(dst, { version: 2, providers: {} }, { replace: true })).toThrow(AccountError);
  expect(existsSync(accountsRoot(dst))).toBe(false);
});

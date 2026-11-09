import { expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { type AccountsDeps, buildRuntime, loadRegistry } from "@marchyo/core";
import {
  type AccountCliDeps,
  IMPORT_CONFLICT,
  runAccountAdd,
  runAccountCopy,
  runAccountImport,
  runAccountList,
  runAccountUse,
} from "../src/commands/agent.ts";
import { captureOutput } from "../../core/tests/agent-usage-fixture.ts";

const SECRET = "sk-ant-oat01-FAKE-ACCOUNT-CLI-SECRET";
const EXEC = join(import.meta.dir, "..", "..", "..", "..", "..", "modules", "nixos", "ai-agent-exec.sh");

function tempAccounts(): AccountsDeps {
  const home = mkdtempSync(join(tmpdir(), "marchyo-agent-account-cli-"));
  mkdirSync(join(home, "proc"));
  return { env: { XDG_STATE_HOME: join(home, "state"), PATH: process.env.PATH }, home, procRoot: join(home, "proc") };
}

// A stand-in for `claude auth login`: signs whatever home it is pointed at in.
function fakeLogin(who: string): AccountCliDeps["run"] {
  return async (_argv, env) => {
    const home = env.CLAUDE_CONFIG_DIR ?? join(env.HOME_FOR_TEST ?? "", ".claude");
    mkdirSync(home, { recursive: true });
    writeFileSync(join(home, ".credentials.json"), JSON.stringify({ claudeAiOauth: { accessToken: `${SECRET}-${who}` } }));
    const accountFile = env.CLAUDE_CONFIG_DIR ? join(home, ".claude.json") : join(env.HOME_FOR_TEST ?? "", ".claude.json");
    writeFileSync(accountFile, JSON.stringify({ oauthAccount: { accountUuid: `uuid-${who}`, emailAddress: `${who}@example.com` } }));
    return 0;
  };
}

function cliDeps(accounts: AccountsDeps, over: Partial<AccountCliDeps> = {}): AccountCliDeps {
  accounts.env.HOME_FOR_TEST = accounts.home;
  return {
    accounts,
    run: fakeLogin("main"),
    ssh: async () => ({ code: 0, stdout: "" }),
    confirm: async () => true,
    interactive: false,
    readStdin: async () => "",
    ...over,
  };
}

const rt = (format: "text" | "json" = "text") => buildRuntime({ format }, {}, false);

test("add signs in the primary first, then an added account in its own home", async () => {
  const a = tempAccounts();
  const first = await captureOutput(() => runAccountAdd(rt(), "claude", undefined, cliDeps(a)));
  expect(first.value).toBe(0);
  const second = await captureOutput(() => runAccountAdd(rt(), "claude", "Work", cliDeps(a, { run: fakeLogin("work") })));
  expect(second.value).toBe(0);
  expect(second.text).toContain("Added Work (work@example.com)");
  const r = loadRegistry(a, "claude");
  expect(r.accounts.map((x) => x.id)).toEqual(["main", "work"]);
  const listed = await captureOutput(() => runAccountList(rt(), "claude", cliDeps(a)));
  expect(listed.text).toContain("Claude Code: manual switching at 95%");
  expect(listed.text).toContain("work@example.com");
  const json = await captureOutput(() => runAccountList(rt("json"), undefined, cliDeps(a)));
  expect(JSON.parse(json.text).map((p: { provider: string }) => p.provider)).toEqual(["claude", "codex", "grok"]);
  for (const out of [first.text, second.text, listed.text, json.text]) expect(out.includes(SECRET)).toBe(false);
  expect((await captureOutput(() => runAccountUse(rt(), "claude", "work", cliDeps(a)))).text).toContain("now use Work");
  expect(await runAccountUse(rt(), "nope", "work", cliDeps(a))).toBe(2);
});

test("copy sends the bundle on ssh stdin; a conflict asks, then replaces", async () => {
  const src = tempAccounts();
  await captureOutput(() => runAccountAdd(rt(), "claude", undefined, cliDeps(src)));
  const dst = tempAccounts();
  const calls: { host: string; args: string[] }[] = [];
  // The "remote" end is the import command in another temp HOME.
  const ssh: AccountCliDeps["ssh"] = async (host, args, input) => {
    calls.push({ host, args });
    const { value, text } = await captureOutput(() =>
      runAccountImport(rt(), { replace: args.includes("--replace") }, cliDeps(dst, { readStdin: async () => input })),
    );
    return { code: value, stdout: text };
  };
  const once = await captureOutput(() => runAccountCopy(rt(), "laptop", [], {}, cliDeps(src, { ssh })));
  expect(once.value).toBe(0);
  expect(calls[0]).toEqual({ host: "laptop", args: ["marchyo", "agent", "account", "import"] });
  const creds = join(dst.home, ".claude", ".credentials.json");
  expect(statSync(creds).mode & 0o777).toBe(0o600);
  expect(statSync(join(dst.home, ".claude")).mode & 0o777).toBe(0o700);
  expect(readFileSync(creds, "utf8")).toContain(SECRET);

  // Non-interactive: refused with a pointer to --replace.
  const refused = await captureOutput(() => runAccountCopy(rt(), "laptop", [], {}, cliDeps(src, { ssh })));
  expect(refused.value).toBe(1);
  expect(refused.text).toContain("--replace");
  // Interactive: one question, then a second send with --replace.
  let asked = 0;
  const confirm = async () => (asked += 1) > 0;
  const replaced = await captureOutput(() =>
    runAccountCopy(rt(), "laptop", ["claude"], {}, cliDeps(src, { ssh, interactive: true, confirm })),
  );
  expect(replaced.value).toBe(0);
  expect(asked).toBe(1);
  expect(calls.at(-1)!.args).toEqual(["marchyo", "agent", "account", "import", "--replace"]);
  for (const out of [once.text, refused.text, replaced.text]) expect(out.includes(SECRET)).toBe(false);
  expect(await runAccountCopy(rt(), "-oProxyCommand=x", [], {}, cliDeps(src, { ssh }))).toBe(2);
});

test("import reports conflicts with its own exit code", async () => {
  const src = tempAccounts();
  await captureOutput(() => runAccountAdd(rt(), "claude", undefined, cliDeps(src)));
  let bundle = "";
  await runAccountCopy(rt(), "h", [], {}, cliDeps(src, { ssh: async (_h, _a, input) => ((bundle = input), { code: 0, stdout: "" }) }));
  const dst = tempAccounts();
  const deps = cliDeps(dst, { readStdin: async () => bundle });
  expect((await captureOutput(() => runAccountImport(rt(), {}, deps))).value).toBe(0);
  expect((await captureOutput(() => runAccountImport(rt(), {}, deps))).value).toBe(IMPORT_CONFLICT);
  const bad = cliDeps(dst, { readStdin: async () => "not json" });
  expect((await captureOutput(() => runAccountImport(rt(), {}, bad))).value).toBe(1);
});

// The wrapper the Nix module installs, run with jq from PATH.
async function wrapperEnv(env: Record<string, string>): Promise<Record<string, string>> {
  const script = readFileSync(EXEC, "utf8").replace("@jq@", "jq");
  const proc = Bun.spawn(["bash", "-c", script, "marchyo-agent-exec", "codex", "env"], {
    env: { PATH: process.env.PATH ?? "", ...env },
    stdout: "pipe",
  });
  const text = await new Response(proc.stdout).text();
  await proc.exited;
  return Object.fromEntries(text.split("\n").filter((l) => l.includes("=")).map((l) => [l.slice(0, l.indexOf("=")), l.slice(l.indexOf("=") + 1)]));
}

test.skipIf(Bun.which("jq") === null)("the agent wrapper selects the active account and pins it", async () => {
  const a = tempAccounts();
  const state = a.env.XDG_STATE_HOME!;
  const base = { HOME: a.home, XDG_STATE_HOME: state };
  expect((await wrapperEnv(base)).CODEX_HOME).toBeUndefined();
  const home = join(state, "marchyo", "agents", "accounts", "codex", "side");
  mkdirSync(home, { recursive: true });
  writeFileSync(
    join(state, "marchyo", "agents", "accounts", "codex.json"),
    JSON.stringify({ active: "side", accounts: [{ id: "main", primary: true }, { id: "side", home }] }),
  );
  const env = await wrapperEnv(base);
  expect(env.CODEX_HOME).toBe(home);
  expect(env.MARCHYO_AGENT_CODEX_HOME).toBe(home);
  // A session started as the primary keeps its subprocesses there.
  expect((await wrapperEnv({ ...base, MARCHYO_AGENT_CODEX_HOME: "" })).CODEX_HOME).toBeUndefined();
  // An explicit home wins.
  expect((await wrapperEnv({ ...base, CODEX_HOME: "/x" })).CODEX_HOME).toBe("/x");
  writeFileSync(
    join(state, "marchyo", "agents", "accounts", "codex.json"),
    JSON.stringify({ active: "evil", accounts: [{ id: "evil", home: "/etc" }] }),
  );
  expect((await wrapperEnv(base)).CODEX_HOME).toBeUndefined();
});

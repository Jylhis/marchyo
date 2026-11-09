import { expect, test } from "bun:test";
import { readFileSync, readdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { beginLogin, loadRegistry, registerLogin, setSwitchMode } from "../src/agent-accounts.ts";
import { ENDPOINTS, collectUsage, readUsageFile, usageDir } from "../src/agent-usage.ts";
import { SECRETS, captureOutput, fakeHome, fixture } from "./agent-usage-fixture.ts";

const NOW = Date.parse("2026-11-05T12:00:00Z");
const WORK_SECRET = "WORKACCT-FAKE-CLAUDE-SECRET-0123456789";

// The fake HOME's Claude login plus an added "Work" account, auto mode at 90%.
function withWorkAccount(fh: ReturnType<typeof fakeHome>) {
  const d = { env: fh.deps.env, home: fh.home, procRoot: join(fh.home, "proc") };
  const oauthAccount = (who: string) => ({
    oauthAccount: { accountUuid: `uuid-${who}`, emailAddress: `${who}@example.com` },
  });
  writeFileSync(join(fh.home, ".claude.json"), JSON.stringify(oauthAccount("main")));
  const pending = beginLogin(d, "claude");
  writeFileSync(join(pending, ".claude.json"), JSON.stringify(oauthAccount("work")));
  writeFileSync(
    join(pending, ".credentials.json"),
    JSON.stringify({ claudeAiOauth: { accessToken: WORK_SECRET, expiresAt: NOW + 3_600_000 } }),
  );
  registerLogin(d, "claude", "Work", pending);
  setSwitchMode(d, "claude", "auto", "90");
  // The primary login is nearly spent, the work one is fresh.
  fh.respond = (url) => {
    if (url.hostname !== "api.anthropic.com") return new Response(fixture("copilot-user.json"));
    const auth = (fh.requests.at(-1)!.init.headers as Record<string, string>).Authorization ?? "";
    const used = auth.includes(WORK_SECRET) ? 10 : 96;
    return new Response(JSON.stringify({ five_hour: { utilization: used, resets_at: "2026-11-05T15:00:00Z" } }));
  };
  return d;
}

test("each account is probed in its own home; auto mode moves to the one with room", async () => {
  const fh = fakeHome(NOW);
  const d = withWorkAccount(fh);
  const file = await collectUsage(fh.deps);
  expect(fh.requests.filter((r) => r.url === ENDPOINTS.claude)).toHaveLength(2);
  expect(loadRegistry(d, "claude").active).toBe("work");
  expect(fh.notices).toHaveLength(1);
  expect(fh.notices[0]).toContain("Work");
  const claude = file.accounts.find((a) => a.provider === "claude")!;
  expect(claude.accounts.map((a) => [a.id, a.active, a.limits[0]?.percent])).toEqual([
    ["main", false, 0.96],
    ["work", true, 0.1],
  ]);
  // The agent's own limits follow the active account.
  expect(file.agents.find((a) => a.id === "claude")!.limits[0]!.percent).toBe(0.1);
  // The record reads back with the account lists and per-account probes, so
  // the 15 s floor holds for every account.
  const back = readUsageFile(join(usageDir(fh.deps.env, fh.home), "usage.json"));
  expect(back.accounts).toEqual(file.accounts);
  expect(Object.keys(back.probes)).toContain("claude:work");
  await collectUsage(fh.deps, { force: true });
  expect(fh.requests.filter((r) => r.url === ENDPOINTS.claude)).toHaveLength(2);
});

test("manual mode keeps the active account and offers the switch in the record", async () => {
  const fh = fakeHome(NOW);
  const d = withWorkAccount(fh);
  setSwitchMode(d, "claude", "manual");
  const file = await collectUsage(fh.deps);
  expect(loadRegistry(d, "claude").active).toBe("main");
  expect(fh.notices).toHaveLength(0);
  const claude = file.accounts.find((a) => a.provider === "claude")!;
  expect(claude.offer).toMatchObject({
    from: { id: "main" },
    to: { id: "work", label: "Work" },
    fromPercent: 96,
  });
});

test("no account credential or home path reaches the record, the cache or the logs", async () => {
  const fh = fakeHome(NOW);
  withWorkAccount(fh);
  const { value, text } = await captureOutput(async () => JSON.stringify(await collectUsage(fh.deps)));
  let leaked = value + text + fh.notices.join("\n");
  const dir = usageDir(fh.deps.env, fh.home);
  for (const f of readdirSync(dir, { withFileTypes: true })) {
    if (f.isFile()) leaked += readFileSync(join(dir, f.name), "utf8");
  }
  leaked += readFileSync(join(dir, "accounts", "claude.json"), "utf8");
  for (const secret of [...SECRETS, WORK_SECRET]) expect(leaked.includes(secret)).toBe(false);
  expect(value.includes("accounts/claude/work")).toBe(false);
});

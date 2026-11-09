import { Database } from "bun:sqlite";
import { expect, test } from "bun:test";
import { mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import {
  ENDPOINTS,
  PROBE_MIN_INTERVAL_MS,
  ProbeError,
  SCAN_REUSE_MS,
  assertEndpoint,
  collectUsage,
  localDay,
  parseClaudeUsage,
  parseCodexRateLimits,
  parseCopilotQuota,
  parseOpenRouterKey,
  parseZaiQuota,
  scanClaudeTranscript,
  scanCodexRollout,
  scanOpencode,
  usageDir,
} from "../src/agent-usage.ts";
import { SECRETS, captureOutput, fakeHome, fixture } from "./agent-usage-fixture.ts";

const NOW = Date.parse("2026-11-05T12:00:00Z");

test("Claude: five-hour, weekly and model-scoped windows, percentages scaled", () => {
  const limits = parseClaudeUsage(JSON.parse(fixture("claude-oauth-usage.json")));
  expect(limits).toEqual([
    { label: "Session (5-hour)", percent: 0.425, resetsAt: "2026-11-05T15:00:00.000Z" },
    { label: "Weekly (7-day)", percent: 0.69, resetsAt: "2026-11-09T08:00:00.000Z" },
    { label: "Fable Weekly", percent: 0.12, resetsAt: "2026-11-09T08:00:00.000Z" },
  ]);
});

test("Codex: general bucket first, model buckets prefixed, epoch resets", () => {
  const limits = parseCodexRateLimits(JSON.parse(fixture("codex-rate-limits.json")).result);
  expect(limits.map((l) => [l.label, l.percent])).toEqual([
    ["5h window", 0.03],
    ["Weekly (7-day)", 0.19],
    ["GPT-6-Codex Weekly (7-day)", 0.5],
  ]);
  expect(limits[0]!.resetsAt).toBe(new Date(1793890000 * 1000).toISOString());
  expect(parseCodexRateLimits({ rateLimits: JSON.parse(fixture("codex-rate-limits.json")).result.rateLimits })).toHaveLength(2);
});

test("Copilot: premium requests as used over entitlement; unlimited has no meter", () => {
  const limits = parseCopilotQuota(JSON.parse(fixture("copilot-user.json")));
  expect(limits).toEqual([
    { label: "Premium requests (monthly)", percent: 0.25, resetsAt: "2026-12-01T00:00:00.000Z" },
  ]);
  expect(parseCopilotQuota({ quota_snapshots: { premium_interactions: { unlimited: true } } })).toEqual([]);
});

test("only the providers' https hosts may receive a credential", () => {
  for (const e of Object.values(ENDPOINTS)) expect(() => assertEndpoint(new URL(e))).not.toThrow();
  for (const bad of [
    "http://api.anthropic.com/api/oauth/usage",
    "https://evil.example/api/oauth/usage",
    "https://api.anthropic.com:8443/x",
    "https://user:pw@api.github.com/x",
    "https://api.anthropic.com.evil.example/x",
  ]) {
    expect(() => assertEndpoint(new URL(bad))).toThrow(ProbeError);
  }
});

test("Claude transcripts count a reply once across its content-block lines", () => {
  const usage = { input_tokens: 10, output_tokens: 5, cache_read_input_tokens: 100, cache_creation_input_tokens: 20 };
  const line = (id: string, ts: string) =>
    JSON.stringify({ type: "assistant", requestId: `r${id}`, timestamp: ts, message: { id, usage } });
  const text = [
    line("a", "2026-11-05T10:00:00Z"),
    line("a", "2026-11-05T10:00:01Z"),
    line("b", "2026-11-04T10:00:00Z"),
    '{"type":"user","message":{"role":"user"}}',
    '{"type":"assistant", torn',
  ].join("\n");
  const days = scanClaudeTranscript(text, NOW);
  expect(days[localDay(Date.parse("2026-11-05T10:00:00Z"))]!.total).toBe(135);
  expect(days[localDay(Date.parse("2026-11-04T10:00:00Z"))]!.input).toBe(10);
});

test("Codex rollouts book each token_count's growth, plain and zstd", async () => {
  const tc = (ts: string, input: number, cached: number, output: number) =>
    JSON.stringify({
      timestamp: ts,
      type: "event_msg",
      payload: {
        type: "token_count",
        info: { total_token_usage: { input_tokens: input, cached_input_tokens: cached, output_tokens: output } },
      },
    });
  const text = [
    tc("2026-11-05T09:00:00Z", 100, 40, 10),
    '{"type":"event_msg","payload":{"type":"token_count","info":null}}',
    tc("2026-11-05T09:05:00Z", 300, 140, 30),
  ].join("\n");
  const day = localDay(Date.parse("2026-11-05T09:00:00Z"));
  const t = scanCodexRollout(text, NOW)[day]!;
  expect([t.input, t.cacheRead, t.output, t.total]).toEqual([160, 140, 30, 330]);

  const fh = fakeHome(NOW);
  const sessions = join(fh.home, ".codex", "sessions", "2026", "11", "05");
  mkdirSync(sessions, { recursive: true });
  writeFileSync(join(sessions, "rollout-a.jsonl"), text);
  writeFileSync(join(sessions, "rollout-b.jsonl.zst"), Bun.zstdCompressSync(Buffer.from(text)));
  const file = await collectUsage({ ...fh.deps, now: () => Date.parse("2026-11-05T10:00:00Z") });
  expect(file.agents.find((a) => a.id === "codex")!.tokens!.today.total).toBe(660);
});

test("opencode: assistant messages in the window, reasoning counted as output", () => {
  const fh = fakeHome();
  const path = join(fh.home, "opencode.db");
  const db = new Database(path);
  db.run("CREATE TABLE message (id text, session_id text, time_created integer, time_updated integer, data text)");
  const add = (t: number, data: unknown) =>
    db.run("INSERT INTO message VALUES (?, 's', ?, ?, ?)", [String(t), t, t, JSON.stringify(data)]);
  const tokens = { input: 5, output: 7, reasoning: 3, cache: { read: 50, write: 1 } };
  add(NOW - 1000, { role: "assistant", tokens, cost: 0.25 });
  add(NOW - 2000, { role: "user", tokens });
  add(NOW - 40 * 86_400_000, { role: "assistant", tokens });
  db.close();
  const days = scanOpencode(path, NOW - 30 * 86_400_000);
  expect(Object.keys(days)).toHaveLength(1);
  expect(days[localDay(NOW - 1000)]).toEqual({ input: 5, output: 10, cacheRead: 50, cacheWrite: 1, total: 66, cost: 0.25 });
});

test("collectUsage probes each provider as its CLI does and caches the record", async () => {
  const fh = fakeHome(NOW);
  const file = await collectUsage(fh.deps);
  const byId = Object.fromEntries(file.agents.map((a) => [a.id, a]));
  expect(byId.claude!.limits).toHaveLength(3);
  expect(byId.codex!.limits).toHaveLength(3);
  expect(byId.copilot!.limits[0]!.percent).toBe(0.25);
  expect(byId.opencode!.ready).toBe(false);

  const claude = fh.requests.find((r) => r.url === ENDPOINTS.claude)!;
  const headers = claude.init.headers as Record<string, string>;
  expect(headers["anthropic-beta"]).toBe("oauth-2025-04-20");
  expect(claude.init.redirect).toBe("error");
  expect(fh.requests.find((r) => r.url === ENDPOINTS.copilot)!.init.redirect).toBe("error");
  expect(fh.requests.every((r) => new URL(r.url).protocol === "https:")).toBe(true);

  const cache = join(usageDir(fh.deps.env, fh.home), "usage.json");
  expect(statSync(cache).mode & 0o777).toBe(0o600);
  expect(JSON.parse(readFileSync(cache, "utf8")).agents).toEqual(file.agents);
});

test("probes wait 15 s even when forced; scans are reused for 20 s unless forced", async () => {
  const fh = fakeHome(NOW);
  await collectUsage(fh.deps);
  const first = fh.requests.length;
  fh.clock.now += PROBE_MIN_INTERVAL_MS - 1;
  await collectUsage(fh.deps, { force: true });
  expect(fh.requests.length).toBe(first);
  fh.clock.now += 2;
  await collectUsage(fh.deps);
  expect(fh.requests.length).toBe(first * 2);

  const transcript = join(fh.home, ".claude", "projects", "p", "s.jsonl");
  const reply = { type: "assistant", timestamp: new Date(fh.clock.now).toISOString(), message: { id: "m", usage: { input_tokens: 9 } } };
  writeFileSync(transcript, JSON.stringify(reply) + "\n");
  const reused = await collectUsage(fh.deps);
  expect(reused.agents[0]!.tokens).toBeUndefined();
  const rescanned = await collectUsage(fh.deps, { force: true });
  expect(rescanned.agents[0]!.tokens!.today.input).toBe(9);
  fh.clock.now += SCAN_REUSE_MS;
  expect((await collectUsage(fh.deps)).agents[0]!.tokens!.last30Days.input).toBe(9);
});

test("a failed probe keeps the last limits and reports a fixed message", async () => {
  const fh = fakeHome(NOW);
  await collectUsage(fh.deps);
  fh.clock.now += PROBE_MIN_INTERVAL_MS;
  fh.respond = () => new Response("{}", { status: 401 });
  const file = await collectUsage(fh.deps);
  const claude = file.agents.find((a) => a.id === "claude")!;
  expect(claude.error).toBe("api.anthropic.com refused the sign-in (status 401)");
  expect(claude.limits).toHaveLength(3);
  expect(claude.limitsFetchedAt).toBe(NOW);
});

test("no credential reaches the record, the cache, the scan index or the logs", async () => {
  const fh = fakeHome(NOW);
  let leaked = "";
  const { value, text } = await captureOutput(async () => {
    const ok = await collectUsage(fh.deps);
    fh.clock.now += PROBE_MIN_INTERVAL_MS;
    // A transport error whose message carries the request (and its token).
    fh.respond = (url) => {
      throw new Error(`fetch ${url} failed with Authorization: Bearer ${SECRETS.join(" ")}`);
    };
    const failed = await collectUsage(fh.deps, { force: true });
    return JSON.stringify([ok, failed]);
  });
  leaked += value + text;
  const dir = usageDir(fh.deps.env, fh.home);
  for (const f of readdirSync(dir)) leaked += readFileSync(join(dir, f), "utf8");
  expect(value).toContain("could not reach api.anthropic.com");
  for (const secret of SECRETS) {
    expect(leaked.includes(secret)).toBe(false);
    expect(leaked.includes(secret.slice(0, 12))).toBe(false);
  }
});

test("an expired Claude sign-in is reported without a request", async () => {
  const fh = fakeHome(NOW);
  writeFileSync(
    join(fh.home, ".claude", ".credentials.json"),
    JSON.stringify({ claudeAiOauth: { accessToken: SECRETS[0], expiresAt: NOW - 1 } }),
  );
  const file = await collectUsage(fh.deps);
  expect(file.agents[0]!.error).toContain("expired");
  expect(fh.requests.some((r) => r.url === ENDPOINTS.claude)).toBe(false);
});

test("an agent with nothing on this machine is not ready and makes no request", async () => {
  const fh = fakeHome(NOW);
  const empty = join(fh.home, "empty");
  mkdirSync(empty);
  const deps = { ...fh.deps, home: empty, env: { ...fh.deps.env, PATH: "", GH_TOKEN: "" } };
  const file = await collectUsage(deps);
  expect(file.agents.every((a) => !a.ready && a.limits.length === 0)).toBe(true);
  expect(fh.requests).toHaveLength(0);
});

test("Z.ai: coding-plan windows by unit and number; no plan is no meter", () => {
  const payload = {
    code: 200,
    data: {
      limits: [
        { type: "TOKENS_LIMIT", unit: 3, number: 5, percentage: 12.5, nextResetTime: 1793890000000 },
        { type: "CREDIT_LIMIT", unit: 6, number: 1, percentage: 80 },
        { type: "TIME_LIMIT", unit: 5, number: 1, percentage: 3 },
        { type: "TOKENS_LIMIT", unit: 9, number: 9, percentage: 3 },
      ],
    },
  };
  expect(parseZaiQuota(payload)).toEqual([
    { label: "Session (5-hour)", percent: 0.125, resetsAt: new Date(1793890000000).toISOString() },
    { label: "Weekly (7-day)", percent: 0.8, resetsAt: "" },
  ]);
  expect(parseZaiQuota({ success: false, msg: "No coding plan found" })).toEqual([]);
  expect(() => parseZaiQuota({ code: "1003" })).toThrow(ProbeError);
  expect(() => parseZaiQuota({})).toThrow(ProbeError);
});

test("OpenRouter: key limit as spent over limit; an unlimited key has no meter", () => {
  const key = (data: object) => ({ data });
  expect(parseOpenRouterKey(key({ limit: 10, limit_remaining: 7.5, limit_reset: "monthly" }))).toEqual([
    { label: "Monthly key limit", percent: 0.25, resetsAt: "" },
  ]);
  expect(parseOpenRouterKey(key({ limit: 10, limit_remaining: -1 }))[0]).toEqual({
    label: "Key limit",
    percent: 1,
    resetsAt: "",
  });
  expect(parseOpenRouterKey(key({ limit: null }))).toEqual([]);
  expect(() => parseOpenRouterKey(key({}))).toThrow(ProbeError);
  expect(() => parseOpenRouterKey(key({ limit: 10 }))).toThrow(ProbeError);
});

test("Z.ai and OpenRouter are probed only with a key, sent to their own hosts", async () => {
  const none = fakeHome(NOW);
  const idle = await collectUsage(none.deps);
  expect(idle.agents.find((a) => a.id === "zai")!.ready).toBe(false);
  expect(idle.agents.find((a) => a.id === "openrouter")!.ready).toBe(false);

  const fh = fakeHome(NOW);
  fh.deps.env.ZAI_API_KEY = "zai-placeholder-value";
  fh.deps.env.OPENROUTER_API_KEY = "sk-or-placeholder-value";
  fh.respond = (url) => {
    if (url.hostname === "api.z.ai") {
      return new Response(
        JSON.stringify({ data: { limits: [{ type: "TOKENS_LIMIT", unit: 3, number: 5, percentage: 50 }] } }),
      );
    }
    if (url.hostname === "openrouter.ai") {
      return new Response(JSON.stringify({ data: { limit: 4, limit_remaining: 1 } }));
    }
    return new Response("{}", { status: 404 });
  };
  const file = await collectUsage(fh.deps);
  const byId = Object.fromEntries(file.agents.map((a) => [a.id, a]));
  expect(byId.zai!.limits[0]!.percent).toBe(0.5);
  expect(byId.openrouter!.limits[0]!.percent).toBe(0.75);
  const zai = fh.requests.find((r) => r.url === ENDPOINTS.zai)!;
  expect((zai.init.headers as Record<string, string>).Authorization).toBe("zai-placeholder-value");
  const or = fh.requests.find((r) => r.url === ENDPOINTS.openrouter)!;
  expect((or.init.headers as Record<string, string>).Authorization).toBe("Bearer sk-or-placeholder-value");
  expect(JSON.stringify(file)).not.toContain("placeholder-value");
});

// Unit tests for shell/Commons/AgentUsage.js (Services/Agents.qml's parsing).
//
// Run: node tests/shell/agent-usage-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const A = require(path.join(__dirname, "..", "..", "shell", "Commons", "AgentUsage.js"));

let passed = 0;

function test(name, fn) {
  try {
    fn();
  } catch (error) {
    console.error("not ok - " + name);
    console.error(String(error.message).replace(/^/gm, "    "));
    process.exit(1);
  }
  passed++;
  console.log("ok - " + name);
}

const record = {
  schemaVersion: 1,
  agents: [
    {
      id: "claude",
      name: "Claude Code",
      ready: true,
      limits: [
        { label: "Session (5-hour)", percent: 0.42, resetsAt: "2026-11-05T15:00:00.000Z" },
        { label: "Weekly (7-day)", percent: 0.91, resetsAt: "2026-11-09T08:00:00.000Z" },
        { label: "broken", percent: "x" },
      ],
      tokens: { today: { total: 1200 } },
    },
    { id: "codex", name: "Codex", ready: true, limits: [], error: "the Codex app-server exited early" },
    { id: "copilot", name: "GitHub Copilot", ready: false, limits: [{ label: "Premium", percent: 1 }] },
  ],
};

test("readyAgents keeps agents in use and their well-formed limits", () => {
  const agents = A.readyAgents(JSON.stringify(record));
  assert.deepEqual(
    agents.map((a) => a.name),
    ["Claude Code", "Codex"],
  );
  assert.equal(agents[0].limits.length, 2);
  assert.equal(agents[0].tokensToday, 1200);
  assert.equal(agents[1].error, "the Codex app-server exited early");
});

test("readyAgents tolerates a missing or garbled file", () => {
  assert.deepEqual(A.readyAgents(""), []);
  assert.deepEqual(A.readyAgents("{not json"), []);
  assert.deepEqual(A.readyAgents('{"agents": 3}'), []);
});

test("tightest picks the fullest limit across agents", () => {
  const t = A.tightest(A.readyAgents(JSON.stringify(record)));
  assert.equal(t.agent, "Claude Code");
  assert.equal(t.label, "Weekly (7-day)");
  assert.equal(t.percent, 0.91);
  assert.equal(A.tightest([]), null);
});

test("resetParts splits the time to reset; unknown is null", () => {
  const now = Date.parse("2026-11-05T12:00:00Z");
  assert.deepEqual(A.resetParts("2026-11-05T15:05:00Z", now), { days: 0, hours: 3, minutes: 5 });
  assert.deepEqual(A.resetParts("2026-11-08T13:00:00Z", now), { days: 3, hours: 1, minutes: 0 });
  assert.deepEqual(A.resetParts("2026-11-05T11:00:00Z", now), { days: 0, hours: 0, minutes: 0 });
  assert.equal(A.resetParts("", now), null);
});

test("level marks 80 % as warn and 95 % as err", () => {
  assert.equal(A.level(0.5), "ok");
  assert.equal(A.level(0.8), "warn");
  assert.equal(A.level(0.95), "err");
});

const withAccounts = {
  ...record,
  accounts: [
    {
      provider: "claude",
      name: "Claude Code",
      switch: "manual",
      threshold: 90,
      accounts: [
        { id: "main", label: "Main", active: true, signedIn: true, limits: [{ label: "Session", percent: 0.96 }] },
        { id: "work", label: "Work", email: "w@example.com", signedIn: true, limits: [{ label: "Session", percent: 0.1 }] },
        { id: "bad id; rm -rf", label: "x", limits: [] },
      ],
      offer: { alert: "notify:main:work", from: { id: "main", label: "Main" }, to: { id: "work", label: "Work" }, fromPercent: 96, toPercent: 10 },
    },
    { provider: "codex", name: "Codex", accounts: [{ id: "main", label: "Main", active: true }] },
    { provider: "evil", accounts: [{ id: "a" }, { id: "b" }] },
  ],
};

test("accountGroups keeps providers with several accounts and safe ids", () => {
  const groups = A.accountGroups(JSON.stringify(withAccounts));
  assert.deepEqual(
    groups.map((g) => g.provider),
    ["claude"],
  );
  const g = groups[0];
  assert.equal(g.mode, "manual");
  assert.equal(g.threshold, 90);
  assert.deepEqual(
    g.accounts.map((a) => [a.id, a.active]),
    [
      ["main", true],
      ["work", false],
    ],
  );
  assert.equal(g.offer.toId, "work");
  assert.equal(g.offer.fromPercent, 96);
  assert.equal(A.accountPeak(g.accounts[0]), 0.96);
  assert.equal(A.accountPeak({ limits: [] }), -1);
});

test("accountGroups drops an offer with an unsafe id and tolerates garbage", () => {
  const bad = JSON.parse(JSON.stringify(withAccounts));
  bad.accounts[0].offer.to.id = "--force";
  assert.equal(A.accountGroups(JSON.stringify(bad))[0].offer, null);
  assert.deepEqual(A.accountGroups(""), []);
  assert.deepEqual(A.accountGroups('{"accounts": 1}'), []);
});

test("limits older than the stale age are stale, unknown ones are not", () => {
  const now = 10 * 3600 * 1000;
  assert.equal(A.isStale(0, now), false);
  assert.equal(A.isStale(now - 30 * 60000, now), false);
  assert.equal(A.isStale(now - 61 * 60000, now), true);
  assert.equal(A.ageMinutes(now - 90 * 60000, now), 90);
  assert.equal(A.ageMinutes(now + 5000, now), 0);
});

test("sign-in errors are told apart from network failures", () => {
  assert.equal(A.needsSignIn("Not signed in: run claude"), true);
  assert.equal(A.needsSignIn("401 Unauthorized"), true);
  assert.equal(A.needsSignIn("token expired, please log in"), true);
  assert.equal(A.needsSignIn("the usage check failed"), false);
  assert.equal(A.needsSignIn(""), false);
  assert.equal(A.needsSignIn(undefined), false);
});

test("readyAgents carries when the limits were fetched", () => {
  const text = JSON.stringify({ agents: [{ id: "claude", name: "Claude", ready: true, limits: [], limitsFetchedAt: 1234 }, { id: "codex", name: "Codex", ready: true, limits: [] }] });
  assert.deepEqual(A.readyAgents(text).map((a) => a.fetchedAt), [1234, 0]);
});

console.log(`# ${passed} passed`);

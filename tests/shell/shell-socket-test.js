// Unit tests for shell/Commons/ShellSocket.js: the unix-socket framing, the
// shared dispatcher, and the shell/shortcuts.json parser.
//
// Run: node tests/shell/shell-socket-test.js   (also a `nix flake check` check)

"use strict";

const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const S = require(path.join(__dirname, "..", "..", "shell", "Commons", "ShellSocket.js"));
const shortcutsPath = path.join(__dirname, "..", "..", "shell", "shortcuts.json");

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

const md5 = (s) => crypto.createHash("md5").update(s).digest("hex");
const req = (...fields) => fields.join(S.UNIT);

const calls = [];
const table = {
  ping: () => "ok",
  togglePanel: (id) => {
    calls.push(id);
    return "ok";
  },
  osdShow: (label, percent, hasBar) => label + percent + hasBar,
  quiet: () => undefined,
  boom: () => {
    throw new Error("kaput");
  },
};

test("the separators are ASCII unit and record separators", () => {
  assert.equal(S.UNIT, "\x1f");
  assert.equal(S.RECORD, "\x1e");
});

test("socketName hashes the shell dir and display like the CLI", () => {
  const name = S.socketName("/nix/store/x/share/marchyo/shell", "wayland-1", md5);
  assert.equal(name, "marchyo-shell-" + md5("/nix/store/x/share/marchyo/shell\nwayland-1").slice(0, 16) + ".sock");
  assert.notEqual(name, S.socketName("/nix/store/x/share/marchyo/shell", "wayland-2", md5));
  assert.match(S.socketName("/a", undefined, md5), /^marchyo-shell-[0-9a-f]{16}\.sock$/);
});

test("handle runs a matching call and replies OK with its output", () => {
  assert.equal(S.handle(table, req("shell", "togglePanel", "audio")), "OK\x1fok\x1e");
  assert.deepEqual(calls, ["audio"]);
  assert.equal(S.handle(table, req("shell", "osdShow", "BRT", "40", "true")), "OK\x1fBRT40true\x1e");
  assert.equal(S.handle(table, req("shell", "quiet")), "OK\x1f\x1e");
});

test("handle skips what it cannot run so the client falls back to qs ipc", () => {
  assert.equal(S.handle(table, req("shell", "nope")), "SKIP\x1e");
  assert.equal(S.handle(table, req("other", "ping")), "SKIP\x1e");
  assert.equal(S.handle(table, req("shell", "togglePanel")), "SKIP\x1e");
  assert.equal(S.handle(table, req("shell", "ping", "extra")), "SKIP\x1e");
  assert.equal(S.handle(table, req("shell", "toString")), "SKIP\x1e");
  assert.equal(S.handle(table, req("shell", "__proto__")), "SKIP\x1e");
});

test("handle rejects malformed and oversized requests", () => {
  assert.match(S.handle(table, "shell"), /^ERR\x1fmalformed request\x1e$/);
  assert.match(S.handle(table, req("shell", "")), /^ERR\x1f/);
  const big = req("shell", "togglePanel", "x".repeat(S.MAX_REQUEST));
  assert.match(S.handle(table, big), /^ERR\x1frequest exceeds \d+ characters\x1e$/);
});

test("feed buffers chunks until the record separator", () => {
  let step = S.feed("", "shell" + S.UNIT + "tog");
  assert.deepEqual(step, { done: false, buffer: "shell\x1ftog" });
  step = S.feed(step.buffer, "glePanel" + S.UNIT + "audio" + S.RECORD + "trailing");
  assert.deepEqual(step, { done: true, record: "shell\x1ftogglePanel\x1faudio" });
});

test("feed stops buffering once a request outgrows the cap", () => {
  let buffer = "";
  let step = null;
  let chunks = 0;
  while (true) {
    step = S.feed(buffer, "x".repeat(1000));
    chunks++;
    if (step.done) break;
    buffer = step.buffer;
  }
  assert.equal(chunks, Math.floor(S.MAX_REQUEST / 1000) + 1);
  assert.match(step.error, /exceeds/);
  const late = S.feed("", "x".repeat(S.MAX_REQUEST + 1) + S.RECORD);
  assert.match(late.error, /exceeds/);
  assert.deepEqual(S.feed("", "x".repeat(S.MAX_REQUEST) + S.RECORD), {
    done: true,
    record: "x".repeat(S.MAX_REQUEST),
  });
  assert.ok(S.IDLE_TIMEOUT_MS > 0 && S.IDLE_TIMEOUT_MS <= 5000);
});

test("a call that throws replies ERR and keeps the separator out of the text", () => {
  assert.equal(S.handle(table, req("shell", "boom")), "ERR\x1fboom: kaput\x1e");
  assert.equal(S.reply("OK", "a\x1eb"), "OK\x1fab\x1e");
});

test("call reports whether it ran, for the global shortcuts", () => {
  assert.deepEqual(S.call(table, "ping", []), { ran: true, output: "ok" });
  assert.deepEqual(S.call(table, "ping", undefined), { ran: true, output: "ok" });
  assert.deepEqual(S.call(table, "missing", []), { ran: false });
});

test("parseShortcuts keeps well-formed entries and drops the rest", () => {
  const list = S.parseShortcuts(
    JSON.stringify([
      { name: "panel.audio", call: "togglePanel", args: ["audio"], description: "Audio" },
      { name: "bar", call: "toggleBar" },
      { name: "bar", call: "toggleBar" },
      { name: "bad name", call: "x" },
      { name: "nocall" },
      null,
    ]),
  );
  assert.deepEqual(list, [
    { name: "panel.audio", call: "togglePanel", args: ["audio"], description: "Audio" },
    { name: "bar", call: "toggleBar", args: [], description: "bar" },
  ]);
  assert.deepEqual(S.parseShortcuts("not json"), []);
  assert.deepEqual(S.parseShortcuts("{}"), []);
});

test("shell/shortcuts.json parses with no entry dropped", () => {
  const raw = JSON.parse(fs.readFileSync(shortcutsPath, "utf8"));
  const parsed = S.parseShortcuts(JSON.stringify(raw));
  assert.equal(parsed.length, raw.length);
  for (const e of parsed) assert.ok(e.description !== e.name, e.name + " has no description");
});

console.log(passed + " passed");

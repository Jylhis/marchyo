"use strict";

const assert = require("node:assert/strict");
const Notify = require("../../shell/Commons/Notify.js");
const Card = require("../../shell/Commons/NotificationCard.js");
const Icons = require("../../shell/Commons/NotificationIcons.js");

const entry = {deadline: 5000, n: "card"};
Card.pauseExpiry(entry, true, 2000);
assert.equal(entry.remaining, 3000);
assert.equal(Notify.partitionExpired([entry], 60000).expired.length, 0);
Card.pauseExpiry(entry, true, 3000);
assert.equal(entry.remaining, 3000);
Card.pauseExpiry(entry, false, 60000);
assert.equal(entry.deadline, 63000);
Card.pauseExpiry(entry, false, 61000);
assert.equal(entry.deadline, 63000);
assert.equal(Notify.partitionExpired([entry], 62999).kept.length, 1);
assert.equal(Notify.partitionExpired([entry], 63000).expired.length, 1);
const persistent = {deadline: 0};
Card.pauseExpiry(persistent, true, 2000);
Card.pauseExpiry(persistent, false, 60000);
assert.equal(persistent.deadline, 0);

const today = new Date(2026, 10, 6, 14, 0).getTime();
assert.deepEqual(Card.age(today - 12 * 60000, today), {kind: "minutes", value: 12});
assert.deepEqual(Card.age(today - 2 * 3600000, today), {kind: "time"});
assert.deepEqual(Card.age(new Date(2026, 10, 5, 23, 59).getTime(), today),
    {kind: "yesterday"});
assert.deepEqual(Card.age(new Date(2026, 10, 3).getTime(), today), {kind: "date"});

const site = Icons.candidates({groupKey: "web:app.slack.com", source: "app.slack.com",
    appIcon: "chromium", app: "Chromium"});
assert.deepEqual(site.themed.slice(0, 2), ["app.slack.com", "slack"]);
assert.deepEqual(site.entries, ["chromium", "Chromium"]);
const app = Icons.candidates({appIcon: "missing", app: "Google Chrome"});
assert.deepEqual(app.themed, ["missing", "google-chrome"]);
assert.ok(!Icons.candidates({appIcon: "https://evil.com/x"}).themed
    .includes("https://evil.com/x"));
assert.equal(Icons.isSymbolic("file:///icons/mail-symbolic.svg"), true);
assert.equal(Icons.isSymbolic("image://icon/mail-symbolic"), true);
assert.equal(Icons.isSymbolic("file:///photos/avatar.png"), false);
console.log("notification card: expiry, age and icon candidates passed");

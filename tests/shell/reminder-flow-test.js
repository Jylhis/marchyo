const assert = require("node:assert/strict");
const flow = require("../../shell/Commons/ReminderFlow.js");

for (const text of ["", "0", "-1", "1.2", "2m", "1e3", "Infinity", "9007199254740992"])
    assert.equal(flow.minutes(text), 0, text);
assert.equal(flow.minutes(" 15 "), 15);
assert.deepEqual(flow.scheduleArgs("marchyo", 15, "a; b", "Reminder"),
    ["marchyo", "reminder", "set", "--", "a; b", "15m"]);
assert.deepEqual(flow.scheduleArgs("marchyo", 1, "  ", "Reminder"),
    ["marchyo", "reminder", "set", "--", "Reminder", "1m"]);
assert.deepEqual(flow.scheduleArgs("marchyo", 1, "--help", "Reminder"),
    ["marchyo", "reminder", "set", "--", "--help", "1m"]);

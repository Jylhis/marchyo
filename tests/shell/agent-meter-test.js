const assert = require("node:assert/strict");
const usage = require("../../shell/Commons/AgentUsage.js");

const groups = usage.accountGroups(JSON.stringify({ accounts: [{
    provider: "claude",
    accounts: [
        { id: "first", limitsFetchedAt: 12345 },
        { id: "second", limitsFetchedAt: "invalid" }
    ]
}] }));
assert.equal(groups[0].accounts[0].fetchedAt, 12345);
assert.equal(groups[0].accounts[1].fetchedAt, 0);

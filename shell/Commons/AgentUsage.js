// Pure helpers for Services/Agents.qml over the record `marchyo agent usage`
// writes to $XDG_STATE_HOME/marchyo/agents/usage.json. Same dual-citizenship
// arrangement as Format.js: QML imports it, tests/shell/agent-usage-test.js
// runs it under Node. No Qt types, no globals, no I/O.

function finitePercent(value) {
    var n = Number(value);
    return isFinite(n) ? Math.max(0, Math.min(1, n)) : -1;
}

// The agents in use, each with its well-formed limits. Anything unreadable
// yields an empty list, never a throw.
function readyAgents(text) {
    var data;
    try {
        data = JSON.parse(text || "");
    } catch (e) {
        return [];
    }
    var agents = data && Array.isArray(data.agents) ? data.agents : [];
    var out = [];
    for (var i = 0; i < agents.length; i++) {
        var a = agents[i] || {};
        if (a.ready !== true || typeof a.name !== "string")
            continue;
        var limits = [];
        var raw = Array.isArray(a.limits) ? a.limits : [];
        for (var j = 0; j < raw.length; j++) {
            var l = raw[j] || {};
            var p = finitePercent(l.percent);
            if (p < 0 || typeof l.label !== "string")
                continue;
            limits.push({
                label: l.label,
                percent: p,
                resetsAt: typeof l.resetsAt === "string" ? l.resetsAt : ""
            });
        }
        var tokens = a.tokens && a.tokens.today ? Number(a.tokens.today.total) || 0 : 0;
        out.push({
            id: String(a.id || ""),
            name: a.name,
            limits: limits,
            tokensToday: tokens,
            fetchedAt: Number(a.limitsFetchedAt) > 0 ? Number(a.limitsFetchedAt) : 0,
            error: typeof a.error === "string" ? a.error : ""
        });
    }
    return out;
}

var PROVIDERS = ["claude", "codex", "grok"];
var ACCOUNT_ID = /^[a-z0-9]+(-[a-z0-9]+)*$/;

function cleanLimits(raw) {
    var out = [];
    var list = Array.isArray(raw) ? raw : [];
    for (var i = 0; i < list.length; i++) {
        var l = list[i] || {};
        var p = finitePercent(l.percent);
        if (p < 0 || typeof l.label !== "string")
            continue;
        out.push({
            label: l.label,
            percent: p,
            resetsAt: typeof l.resetsAt === "string" ? l.resetsAt : ""
        });
    }
    return out;
}

// Providers that have more than one account, each with its accounts and the
// standing switch offer, if any. Ids are checked because they go into a
// `marchyo agent account use` argv.
function accountGroups(text) {
    var data;
    try {
        data = JSON.parse(text || "");
    } catch (e) {
        return [];
    }
    var groups = data && Array.isArray(data.accounts) ? data.accounts : [];
    var out = [];
    for (var i = 0; i < groups.length; i++) {
        var g = groups[i] || {};
        if (PROVIDERS.indexOf(g.provider) < 0 || !Array.isArray(g.accounts))
            continue;
        var accounts = [];
        for (var j = 0; j < g.accounts.length; j++) {
            var a = g.accounts[j] || {};
            if (typeof a.id !== "string" || !ACCOUNT_ID.test(a.id))
                continue;
            accounts.push({
                id: a.id,
                label: typeof a.label === "string" && a.label !== "" ? a.label : a.id,
                email: typeof a.email === "string" ? a.email : "",
                plan: typeof a.plan === "string" ? a.plan : "",
                active: a.active === true,
                signedIn: a.signedIn === true,
                limits: cleanLimits(a.limits),
                fetchedAt: Number(a.limitsFetchedAt) > 0 ? Number(a.limitsFetchedAt) : 0,
                error: typeof a.error === "string" ? a.error : ""
            });
        }
        if (accounts.length < 2)
            continue;
        var o = g.offer || null;
        var offer = null;
        if (o && typeof o.alert === "string" && o.to && typeof o.to.id === "string" && ACCOUNT_ID.test(o.to.id))
            offer = {
                alert: o.alert,
                fromLabel: o.from && typeof o.from.label === "string" ? o.from.label : "",
                toId: o.to.id,
                toLabel: typeof o.to.label === "string" ? o.to.label : o.to.id,
                fromPercent: Math.round(Number(o.fromPercent) || 0),
                toPercent: Math.round(Number(o.toPercent) || 0)
            };
        out.push({
            provider: g.provider,
            name: typeof g.name === "string" ? g.name : g.provider,
            mode: g.switch === "auto" ? "auto" : "manual",
            threshold: Math.round(Number(g.threshold) || 95),
            accounts: accounts,
            offer: offer
        });
    }
    return out;
}

// An account's fullest limit as a fraction, or -1 when none is known.
function accountPeak(account) {
    var best = -1;
    for (var i = 0; i < account.limits.length; i++)
        best = Math.max(best, account.limits[i].percent);
    return best;
}

// The limit closest to running out across every agent, or null.
function tightest(agents) {
    var best = null;
    for (var i = 0; i < agents.length; i++) {
        var limits = agents[i].limits;
        for (var j = 0; j < limits.length; j++) {
            if (best === null || limits[j].percent > best.percent)
                best = {
                    agent: agents[i].name,
                    label: limits[j].label,
                    percent: limits[j].percent,
                    resetsAt: limits[j].resetsAt
                };
        }
    }
    return best;
}

// Time until `iso` as { days, hours, minutes }, or null when unknown.
function resetParts(iso, nowMs) {
    var t = Date.parse(iso || "");
    if (isNaN(t))
        return null;
    var mins = Math.max(0, Math.round((t - nowMs) / 60000));
    return {
        days: Math.floor(mins / 1440),
        hours: Math.floor((mins % 1440) / 60),
        minutes: mins % 60
    };
}

// Severity bucket for a meter colour: "ok", "warn" (>= 80 %), "err" (>= 95 %).
function level(percent) {
    if (percent >= 0.95)
        return "err";
    if (percent >= 0.8)
        return "warn";
    return "ok";
}

// Limits older than this many minutes are shown as stale.
var STALE_MINUTES = 60;

// Whether limits fetched at `fetchedAtMs` (0 = never) are too old at `nowMs`.
function isStale(fetchedAtMs, nowMs) {
    if (!(fetchedAtMs > 0))
        return false;
    return (nowMs - fetchedAtMs) / 60000 > STALE_MINUTES;
}

// Whole minutes since `fetchedAtMs`, never negative.
function ageMinutes(fetchedAtMs, nowMs) {
    return Math.max(0, Math.floor((nowMs - fetchedAtMs) / 60000));
}

// Whether a probe error says the agent is not signed in (as opposed to a
// network or server failure).
function needsSignIn(error) {
    return /sign(ed)?.?in|signed out|log(ged)?.?(in|out)|not authenticated|unauthori[sz]ed|credential|expired token|\b40[13]\b/i.test(String(error || ""));
}

if (typeof module !== "undefined")
    module.exports = {
        STALE_MINUTES: STALE_MINUTES,
        isStale: isStale,
        ageMinutes: ageMinutes,
        needsSignIn: needsSignIn,
        readyAgents: readyAgents,
        accountGroups: accountGroups,
        accountPeak: accountPeak,
        tightest: tightest,
        resetParts: resetParts,
        level: level
    };

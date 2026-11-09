// Framing and dispatch for the shell's unix socket (shell.qml SocketServer),
// and the parser for shell/shortcuts.json. Pure, so tests/shell/
// shell-socket-test.js can load it under Node.
//
// A request is one record: target, function and arguments joined by the unit
// separator (0x1f) and ended by the record separator (0x1e). The reply is
// "OK" 0x1f <output> 0x1e once the call has run, "SKIP" 0x1e when nothing ran
// (another target, an unknown function, the wrong argument count) so the
// client falls back to `qs ipc`, or "ERR" 0x1f <message> 0x1e for a request
// that is too large or a call that threw.

var UNIT = "\u001f";
var RECORD = "\u001e";
var TARGET = "shell";
var MAX_REQUEST = 4096;
// A connection that has not sent a whole request by then is closed.
var IDLE_TIMEOUT_MS = 2000;

// One step of a connection's receive buffer: the raw chunks arrive unsplit,
// so the size cap holds while the request is still incomplete.
// {done: false, buffer} waits for more; {done: true, record} or
// {done: true, error} ends the connection.
function feed(buffer, chunk) {
    var next = String(buffer) + String(chunk);
    var end = next.indexOf(RECORD);
    if (end >= 0 && end <= MAX_REQUEST)
        return {
            done: true,
            record: next.slice(0, end)
        };
    if (end > MAX_REQUEST || next.length > MAX_REQUEST)
        return {
            done: true,
            error: "request exceeds " + MAX_REQUEST + " characters"
        };
    return {
        done: false,
        buffer: next
    };
}

function socketName(shellDir, waylandDisplay, md5) {
    return "marchyo-shell-" + md5(String(shellDir) + "\n" + String(waylandDisplay || "")).slice(0, 16) + ".sock";
}

function reply(kind, text) {
    return text === undefined ? kind + RECORD : kind + UNIT + String(text).split(RECORD).join("") + RECORD;
}

function parseRequest(record) {
    var raw = String(record);
    if (raw.length > MAX_REQUEST)
        return {
            error: "request exceeds " + MAX_REQUEST + " characters"
        };
    var fields = raw.split(UNIT);
    if (fields.length < 2 || fields[1] === "")
        return {
            error: "malformed request"
        };
    return {
        target: fields[0],
        name: fields[1],
        args: fields.slice(2)
    };
}

function lookup(table, name) {
    if (!Object.prototype.hasOwnProperty.call(table, name))
        return null;
    return typeof table[name] === "function" ? table[name] : null;
}

// Run `name` from `table` when its arity matches. {ran, output} so the
// GlobalShortcut path and the socket path share one dispatcher.
function call(table, name, args) {
    var fn = lookup(table, name);
    var argv = args || [];
    if (fn === null || fn.length !== argv.length)
        return {
            ran: false
        };
    var out = fn.apply(null, argv);
    return {
        ran: true,
        output: out === undefined || out === null ? "" : String(out)
    };
}

function handle(table, record) {
    var req = parseRequest(record);
    if (req.error)
        return reply("ERR", req.error);
    if (req.target !== TARGET)
        return reply("SKIP");
    try {
        var result = call(table, req.name, req.args);
        return result.ran ? reply("OK", result.output) : reply("SKIP");
    } catch (e) {
        return reply("ERR", req.name + ": " + (e && e.message ? e.message : e));
    }
}

// shell/shortcuts.json: [{name, call, args, description}]. Malformed entries
// are dropped, so one bad line cannot unregister the rest.
function parseShortcuts(text) {
    var list;
    try {
        list = JSON.parse(String(text || "[]"));
    } catch (e) {
        return [];
    }
    if (!Array.isArray(list))
        return [];
    var out = [];
    var seen = {};
    for (var i = 0; i < list.length; i++) {
        var e = list[i];
        if (!e || typeof e.name !== "string" || !/^[A-Za-z][A-Za-z0-9.]*$/.test(e.name))
            continue;
        if (typeof e.call !== "string" || seen[e.name])
            continue;
        var args = Array.isArray(e.args) ? e.args.map(String) : [];
        seen[e.name] = true;
        out.push({
            name: e.name,
            call: e.call,
            args: args,
            description: typeof e.description === "string" ? e.description : e.name
        });
    }
    return out;
}

// Node (tests) picks these up; QML ignores the guard.
if (typeof module !== "undefined")
    module.exports = {
        UNIT: UNIT,
        RECORD: RECORD,
        TARGET: TARGET,
        MAX_REQUEST: MAX_REQUEST,
        IDLE_TIMEOUT_MS: IDLE_TIMEOUT_MS,
        feed: feed,
        socketName: socketName,
        reply: reply,
        parseRequest: parseRequest,
        call: call,
        handle: handle,
        parseShortcuts: parseShortcuts
    };

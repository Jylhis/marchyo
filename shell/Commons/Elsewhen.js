// Pure logic for the Elsewhen world-clock panel: zone offsets, clock
// formatting, geocoder and forecast parsing, and the persisted city list.
// QML's JS engine has no Intl, so offsets come from one `date` probe and the
// rows tick against them. No Qt types, no I/O (see Format.js for why).

var ZONE_RE = /^[A-Za-z0-9_+-]+(\/[A-Za-z0-9_+-]+){0,2}$/;
var WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
var MAX_CITIES = 24;

// Well-known cities seeded on first run, in eastward order.
var DEFAULT_CITIES = [
    {name: "Los Angeles", tz: "America/Los_Angeles", lat: 34.05, lon: -118.24},
    {name: "New York", tz: "America/New_York", lat: 40.71, lon: -74.01},
    {name: "London", tz: "Europe/London", lat: 51.51, lon: -0.13},
    {name: "Dubai", tz: "Asia/Dubai", lat: 25.2, lon: 55.27},
    {name: "Tokyo", tz: "Asia/Tokyo", lat: 35.68, lon: 139.69}
];

function validZone(tz) {
    return typeof tz === "string" && tz.length <= 64 && ZONE_RE.test(tz);
}

// "+0530" -> 330, "-0800" -> -480; anything else -> null.
function parseOffsetMinutes(z) {
    var m = /^([+-])(\d{2})(\d{2})$/.exec(String(z));
    if (!m)
        return null;
    var minutes = parseInt(m[2], 10) * 60 + parseInt(m[3], 10);
    return m[1] === "-" ? -minutes : minutes;
}

// Output of the offset probe: one "+0200 CEST" line per requested zone, in
// request order. Returns {zone: {min, abbr}}; unparsable lines are skipped.
function parseOffsets(text, zones) {
    var lines = String(text || "").split("\n");
    var out = {};
    for (var i = 0; i < zones.length; i++) {
        var parts = (lines[i] || "").trim().split(/\s+/);
        var min = parseOffsetMinutes(parts[0]);
        if (min !== null)
            out[zones[i]] = {min: min, abbr: parts[1] || ""};
    }
    return out;
}

// 330 -> "UTC+5:30", 0 -> "UTC", -480 -> "UTC-8".
function offsetLabel(min) {
    if (min === 0)
        return "UTC";
    var abs = Math.abs(min);
    var m = abs % 60;
    return "UTC" + (min < 0 ? "-" : "+") + Math.floor(abs / 60) + (m ? ":" + pad2(m) : "");
}

// Difference to home: 180 -> "+3h", -330 -> "-5h30", 0 -> "0h".
function relativeOffset(cityMin, homeMin) {
    var d = cityMin - homeMin;
    if (d === 0)
        return "0h";
    var abs = Math.abs(d);
    var m = abs % 60;
    return (d < 0 ? "-" : "+") + Math.floor(abs / 60) + "h" + (m ? pad2(m) : "");
}

// Wall-clock fields of `nowMs` in a zone `offsetMin` from UTC.
function zoneParts(nowMs, offsetMin) {
    var d = new Date(nowMs + offsetMin * 60000);
    return {
        year: d.getUTCFullYear(),
        month: d.getUTCMonth() + 1,
        day: d.getUTCDate(),
        hour: d.getUTCHours(),
        minute: d.getUTCMinutes(),
        weekday: d.getUTCDay()
    };
}

function pad2(n) {
    return (n < 10 ? "0" : "") + n;
}

function formatClock(p, use24h) {
    if (use24h)
        return pad2(p.hour) + ":" + pad2(p.minute);
    var h = p.hour % 12 === 0 ? 12 : p.hour % 12;
    return h + ":" + pad2(p.minute) + (p.hour < 12 ? " AM" : " PM");
}

function weekdayShort(p) {
    return WEEKDAYS[p.weekday];
}

// Calendar-day distance of a zone's date from the reference zone's: -1, 0, 1.
function dayDelta(p, ref) {
    var a = Date.UTC(p.year, p.month - 1, p.day);
    var b = Date.UTC(ref.year, ref.month - 1, ref.day);
    return Math.round((a - b) / 86400000);
}

// Daylight as a rough hour test, enough for a sun or moon glyph.
function isDaytime(p) {
    return p.hour >= 6 && p.hour < 18;
}

// Equirectangular projection of lat/lon into a w x h box.
function project(lat, lon, w, h) {
    return {x: (lon + 180) / 360 * w, y: (90 - lat) / 180 * h};
}

function geocodeUrl(query, count) {
    return "https://geocoding-api.open-meteo.com/v1/search?count=" + (count || 5)
        + "&language=en&format=json&name=" + encodeURIComponent(String(query).trim());
}

// Open-Meteo geocoding answer -> [{name, region, country, lat, lon, tz}].
// Network input: only a real list, capped at `max`; entries without a valid
// zone and coordinates are dropped.
function parseGeocode(text, max) {
    var data = null;
    try {
        data = JSON.parse(text);
    } catch (e) {
        return [];
    }
    var rows = data && Array.isArray(data.results) ? data.results : [];
    var out = [];
    for (var i = 0; i < rows.length && out.length < (max || 5); i++) {
        var r = rows[i] || {};
        if (typeof r.name !== "string" || !validZone(r.timezone))
            continue;
        if (typeof r.latitude !== "number" || typeof r.longitude !== "number")
            continue;
        out.push({
            name: r.name,
            region: typeof r.admin1 === "string" ? r.admin1 : "",
            country: typeof r.country_code === "string" ? r.country_code : "",
            lat: r.latitude,
            lon: r.longitude,
            tz: r.timezone
        });
    }
    return out;
}

// One request for every city: Open-Meteo takes comma-separated coordinates.
function weatherUrl(cities) {
    var lat = cities.map(function (c) {
        return c.lat;
    }).join(",");
    var lon = cities.map(function (c) {
        return c.lon;
    }).join(",");
    return "https://api.open-meteo.com/v1/forecast?current=temperature_2m&latitude=" + lat + "&longitude=" + lon;
}

// Forecast answer -> Celsius values (null where missing), one per requested
// city. A single city comes back as an object, several as an array.
function parseWeather(text, n) {
    var data = null;
    try {
        data = JSON.parse(text);
    } catch (e) {
        return [];
    }
    var rows = Array.isArray(data) ? data : [data];
    var out = [];
    for (var i = 0; i < n; i++) {
        var cur = rows[i] && rows[i].current;
        out.push(cur && typeof cur.temperature_2m === "number" ? cur.temperature_2m : null);
    }
    return out;
}

function formatTemp(c, useF) {
    if (c === null || c === undefined)
        return "";
    return useF ? Math.round(c * 9 / 5 + 32) + "°F" : Math.round(c) + "°C";
}

function makeState(home, use24h, useF, cities) {
    return {home: home, use24h: use24h, useF: useF, cities: cities};
}

function defaultState() {
    return makeState("", true, false, DEFAULT_CITIES.map(function (c) {
        return cleanCity(c);
    }));
}

function cleanPeople(people) {
    if (!Array.isArray(people))
        return [];
    return people.filter(function (p) {
        return typeof p === "string" && p !== "";
    }).map(function (p) {
        return p.slice(0, 40);
    }).slice(0, 8);
}

function cleanCity(c) {
    if (!c || typeof c.name !== "string" || !validZone(c.tz))
        return null;
    return {
        name: c.name.slice(0, 64),
        tz: c.tz,
        lat: typeof c.lat === "number" ? c.lat : 0,
        lon: typeof c.lon === "number" ? c.lon : 0,
        people: cleanPeople(c.people)
    };
}

// Persisted state text -> state; anything unusable yields the defaults.
function normalizeState(text) {
    var obj = null;
    try {
        obj = JSON.parse(text);
    } catch (e) {
        return defaultState();
    }
    if (!obj || !Array.isArray(obj.cities))
        return defaultState();
    var cities = obj.cities.map(cleanCity).filter(function (c) {
        return c !== null;
    }).slice(0, MAX_CITIES);
    return makeState(validZone(obj.home) ? obj.home : "", obj.use24h !== false, obj.useF === true, cities);
}

function sameCity(a, b) {
    return a.tz === b.tz && a.name === b.name;
}

// The state functions below return a new state and never mutate the input.
function withCity(state, city) {
    var c = cleanCity(city);
    if (!c || state.cities.length >= MAX_CITIES || state.cities.some(function (x) {
        return sameCity(x, c);
    }))
        return state;
    return makeState(state.home, state.use24h, state.useF, state.cities.concat([c]));
}

function withoutCity(state, index) {
    return makeState(state.home, state.use24h, state.useF, state.cities.filter(function (_, i) {
        return i !== index;
    }));
}

// `names` is a comma-separated string, as typed.
function withPeople(state, index, names) {
    var list = String(names).split(",").map(function (s) {
        return s.trim();
    });
    return makeState(state.home, state.use24h, state.useF, state.cities.map(function (c, i) {
        return i === index ? cleanCity({name: c.name, tz: c.tz, lat: c.lat, lon: c.lon, people: list}) : c;
    }));
}

// Tapping the home city again returns home to the local zone ("").
function withHome(state, tz) {
    return makeState(state.home === tz ? "" : tz, state.use24h, state.useF, state.cities);
}

function withToggle(state, key) {
    var next = makeState(state.home, state.use24h, state.useF, state.cities);
    next[key] = !state[key];
    return next;
}

// Node (tests) picks these up; QML ignores the guard.
if (typeof module !== "undefined")
    module.exports = {
        validZone: validZone,
        parseOffsetMinutes: parseOffsetMinutes,
        parseOffsets: parseOffsets,
        offsetLabel: offsetLabel,
        relativeOffset: relativeOffset,
        zoneParts: zoneParts,
        formatClock: formatClock,
        weekdayShort: weekdayShort,
        dayDelta: dayDelta,
        isDaytime: isDaytime,
        project: project,
        geocodeUrl: geocodeUrl,
        parseGeocode: parseGeocode,
        weatherUrl: weatherUrl,
        parseWeather: parseWeather,
        formatTemp: formatTemp,
        defaultState: defaultState,
        normalizeState: normalizeState,
        withCity: withCity,
        withoutCity: withoutCity,
        withPeople: withPeople,
        withHome: withHome,
        withToggle: withToggle
    };

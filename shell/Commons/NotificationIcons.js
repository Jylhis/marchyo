// Adapted from omacom/omarchy (MIT, see ../compat/LICENSE.omarchy),
// shell/plugins/notifications/Icons.js at 6194f4606c585da8b839b87df9120b7d796afedf.

function slug(text) {
    return String(text || "").slice(0, 256).toLowerCase()
        .replace(/[^a-z0-9._-]+/g, "-").replace(/^[-.]+|[-.]+$/g, "").slice(0, 100);
}

function unique(names) {
    return names.filter((name, i) => name && names.indexOf(name) === i);
}

function siteNames(source) {
    const host = String(source || "").toLowerCase();
    if (!/^[a-z0-9.-]+\.[a-z]+$/.test(host))
        return [];
    const prefixes = ["www", "app", "web", "my", "m"];
    const labels = host.split(".").filter(label => prefixes.indexOf(label) < 0);
    return unique([host, labels.length >= 2 ? labels[labels.length - 2] : "", labels[0]]);
}

function candidates(row) {
    row = row || {};
    const site = String(row.groupKey || "").indexOf("web:") === 0 ? siteNames(row.source) : [];
    const own = [row.appIcon || "", row.source || "", row.app || ""];
    let themed = site.length ? site : [row.appIcon];
    for (const name of own)
        themed = themed.concat([name, slug(name)]);
    return {
        themed: unique(themed.filter(name => /^[A-Za-z0-9_][A-Za-z0-9_.-]{0,255}$/.test(name))),
        entries: unique(site.length ? [row.appIcon, row.app] : own)
    };
}

function isSymbolic(source) {
    const text = String(source || "").split("?")[0];
    return /-symbolic$/.test(text) || text.indexOf("/symbolic/") >= 0
        || /-symbolic\.[A-Za-z]+$/.test(text);
}

if (typeof module !== "undefined" && module.exports)
    module.exports = {candidates: candidates, isSymbolic: isSymbolic};

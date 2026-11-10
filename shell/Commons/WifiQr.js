function escapeField(value) {
  return String(value || "").replace(/([\\;,:"])/g, "\\$1");
}

function payload(ssid, security, password) {
  if (
    !ssid ||
    (security && security !== "wpa-psk" && security !== "sae") ||
    (security && !password)
  )
    return "";
  return (
    "WIFI:T:" +
    (security ? "WPA" : "nopass") +
    ";S:" +
    escapeField(ssid) +
    (security ? ";P:" + escapeField(password) : "") +
    ";;"
  );
}

function parseAscii(raw) {
  var rows = String(raw || "")
    .replace(/\r/g, "")
    .split("\n");
  if (rows[rows.length - 1] === "") rows.pop();
  var size = rows.length;
  if (
    size < 29 ||
    size > 185 ||
    rows.some(function (row) {
      return row.length !== size * 2 || !/^(##|  )+$/.test(row);
    })
  )
    return { size: 0, cells: [] };
  var cells = [];
  rows.forEach(function (row, y) {
    for (var x = 0; x < size; x++)
      if (row.slice(x * 2, x * 2 + 2) === "##") cells.push({ x: x, y: y });
  });
  return { size: size, cells: cells };
}

if (typeof module !== "undefined")
  module.exports = {
    escapeField: escapeField,
    payload: payload,
    parseAscii: parseAscii,
  };

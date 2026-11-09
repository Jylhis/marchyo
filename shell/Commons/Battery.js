function glyph(level, charging, full) {
  var normal = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
  var plugged = ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"];
  var index = Math.max(0, Math.min(9, Math.floor(level / 10)));
  return full ? "󰂅" : (charging ? plugged : normal)[index];
}

function holding(
  present,
  pluggedIn,
  state,
  pendingCharge,
  fullyCharged,
  level,
) {
  return (
    present &&
    pluggedIn &&
    (state === pendingCharge || (state === fullyCharged && level < 99))
  );
}

function warningThreshold(value) {
  return typeof value === "number" &&
    isFinite(value) &&
    value >= 0 &&
    value <= 100
    ? value
    : 10;
}

function warningState(
  present,
  level,
  discharging,
  charging,
  threshold,
  notified,
) {
  if (!present || !isFinite(level))
    return { notify: false, notified: notified };
  if (charging || level > threshold) return { notify: false, notified: false };
  var notify = discharging && level <= threshold && !notified;
  return { notify: notify, notified: notified || notify };
}

if (typeof module !== "undefined")
  module.exports = {
    glyph: glyph,
    holding: holding,
    warningThreshold: warningThreshold,
    warningState: warningState,
  };

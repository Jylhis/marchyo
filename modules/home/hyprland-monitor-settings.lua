-- Display settings chosen in the shell's display panel, applied on top of
-- marchyo.monitors. Modelled on Omarchy's default/hypr/monitor-settings.lua
-- (MIT).
--
-- The panel keeps one tab-separated line per display in
-- $XDG_STATE_HOME/marchyo/monitors/settings:
--
--   enabled  mode  position  scale  transform  mirror  identity
--
-- `enabled` is "1", "0" or empty; `mirror` is "internal" when the display
-- mirrors the built-in panel; any field may be empty, and an empty one leaves
-- the declarative value alone. The identity is the description Hyprland
-- reports (make, model, serial), not the connector: a dock renames its
-- connectors between plugs, so a rule naming DP-1 would hand one display's
-- mode to whatever turns up on that port next.
--
-- The file is state, not configuration: it survives rebuilds, and
-- `marchyo monitor reset` removes it.
--
-- modules/home/hyprland.nix loads this file with dofile after the declarative
-- monitor rules, so a choice made in the panel wins over marchyo.monitors and
-- a reload settles on it in one go. It is applied again when a display
-- arrives, skipping one that already runs as saved.

return function()
  local function state_home()
    local xdg = os.getenv("XDG_STATE_HOME")
    if xdg and xdg ~= "" then
      return xdg
    end
    return (os.getenv("HOME") or "") .. "/.local/state"
  end

  local STATE_FILE = state_home() .. "/marchyo/monitors/settings"
  local SAFE_NAME = "^[%w._-]+$"

  local M = {}

  local function present(value)
    if value == nil or value == "" then
      return nil
    end
    return value
  end

  local function load()
    local settings = {}
    local file = io.open(STATE_FILE, "r")
    if not file then
      return settings
    end

    for line in file:lines() do
      local enabled, mode, position, scale, transform, mirror, identity =
        line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]+)$")
      if identity then
        settings[identity] = {
          enabled = present(enabled),
          mode = present(mode),
          position = present(position),
          scale = tonumber(scale),
          transform = tonumber(transform),
          mirror = present(mirror),
        }
      end
    end

    file:close()
    return settings
  end

  local function identity_of(monitor)
    local description = monitor.description or ""
    return description ~= "" and description or monitor.name
  end

  local function internal(monitor)
    return monitor.name:match("^eDP") or monitor.name:match("^LVDS") or monitor.name:match("^DSI")
  end

  -- Displays that report the same description cannot be told apart, so their
  -- positions are left to the declarative rules.
  local function duplicated(monitors)
    local seen, twice = {}, {}
    for _, monitor in ipairs(monitors) do
      local identity = identity_of(monitor)
      if seen[identity] then
        twice[identity] = true
      end
      seen[identity] = true
    end
    return twice
  end

  local function built_in(monitors)
    for _, monitor in ipairs(monitors) do
      if internal(monitor) then
        return monitor.name
      end
    end
    return nil
  end

  -- Whether a display already runs as saved.
  local function matches(monitor, saved)
    if saved.scale and math.abs((monitor.scale or 0) - saved.scale) > 0.001 then
      return false
    end

    if saved.position then
      local x, y = saved.position:match("^(-?%d+)x(-?%d+)$")
      if tonumber(x) ~= monitor.x or tonumber(y) ~= monitor.y then
        return false
      end
    end

    if saved.mode then
      local width, height, rate = saved.mode:match("^(%d+)x(%d+)@?([%d.]*)$")
      if tonumber(width) ~= monitor.width or tonumber(height) ~= monitor.height then
        return false
      end
      if rate ~= "" and math.abs((monitor.refresh_rate or 0) - tonumber(rate)) > 0.5 then
        return false
      end
    end

    if saved.transform and saved.transform ~= (monitor.transform or 0) then
      return false
    end

    if saved.enabled == "0" and not monitor.disabled then
      return false
    end

    if saved.mirror == "internal" and not monitor.is_mirror then
      return false
    end

    return true
  end

  -- Only what was chosen: hl.monitor updates the connector's existing rule, so
  -- anything never set in the panel keeps what marchyo.monitors gives it.
  local function rule(name, saved, keep_position, internal_name)
    if saved.enabled == "0" then
      return { output = name, disabled = true }
    end
    return {
      output = name,
      mode = saved.mode,
      position = (not keep_position) and saved.position or nil,
      scale = saved.scale,
      transform = saved.transform,
      mirror = saved.mirror and internal_name or nil,
    }
  end

  -- Apply the saved settings of the connected displays, or just of `only`.
  -- While the config loads every one is applied, since the rules just read
  -- from marchyo.monitors would otherwise win; afterwards one already running
  -- as saved is left alone.
  function M.apply(loading, only)
    local settings = load()
    if next(settings) == nil then
      return
    end

    local monitors = hl.get_monitors()
    local twice = duplicated(monitors)
    local internal_name = built_in(monitors)

    for _, monitor in ipairs(monitors) do
      local identity = identity_of(monitor)
      local saved = settings[identity]
      if
        saved
        and monitor.name:match(SAFE_NAME)
        and (not only or monitor.name == only)
        and (loading or not matches(monitor, saved))
      then
        local mirror_ok = saved.mirror == "internal" and internal_name ~= nil and internal_name ~= monitor.name
        local copy = {}
        for key, value in pairs(saved) do
          copy[key] = value
        end
        copy.mirror = mirror_ok and "internal" or nil
        hl.monitor(rule(monitor.name, copy, twice[identity], internal_name))
      end
    end
  end

  hl.on("hyprland.start", function()
    M.apply(false)
  end)

  hl.on("monitor.added", function(monitor)
    M.apply(false, monitor and monitor.name)
  end)

  M.apply(true)

  marchyo = marchyo or {}
  marchyo.monitorSettings = M

  return M
end

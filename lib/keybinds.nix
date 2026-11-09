# The marchyo Hyprland bind table: every keybind marchyo ships, in one list.
#
# modules/home/keybinds.nix renders it into
# `wayland.windowManager.hyprland.settings.bind`. Each entry is data:
#
#   combo        Lua key string ("SUPER + SHIFT + A") in the default layout,
#                which follows the Omarchy 4.5 planes: Super for the system,
#                Super+Shift for apps, Super+Ctrl for panels and menus,
#                Super+Ctrl+Alt for quick actions. null: not bound there.
#   legacy       The chord under marchyo.keyboard.legacyBinds, when it
#                differs from `combo`; null: not bound there.
#   description  What the bind does; every entry has one.
#   group        Cheat-sheet section.
#   action       Dispatcher (lib/hyprland-lua.nix value).
#   when         Condition from `ctx`; false drops the entry (default true).
#   opts         Extra hl.bind options (locked, release, ...).
#   hidden       Kept out of the cheat sheet and rendered without a
#                description (lock-key pass-through, hardware keys).
#
# `ctx` carries the feature flags and commands the module resolves from the
# NixOS and Home Manager config; see modules/home/keybinds.nix.
{ lib }:
let
  hlua = import ./hyprland-lua.nix { inherit lib; };
  inherit (hlua)
    mkLuaInline
    dsp
    exec
    execLua
    global
    luaStr
    execInTerminal
    execInTerminalAs
    execInPlainTerminal
    ;

  entry = group: combo: description: action: {
    inherit
      group
      combo
      description
      action
      ;
  };
  onlyIf = cond: map (e: e // { when = (e.when or true) && cond; });
  hidden = e: e // { hidden = true; };
  withOpts = opts: e: e // { opts = (e.opts or { }) // opts; };
  moved = old: e: e // { legacy = old; };
  newBind = e: e // { legacy = null; };
  legacyOnly =
    e:
    e
    // {
      combo = null;
      legacy = e.combo;
    };

  # Hyprland's built-in tiled layouts, in the order Super+L walks them on the
  # focused workspace.
  layouts = [
    "dwindle"
    "scrolling"
    "master"
  ];
  cycleLayout =
    step:
    mkLuaInline ''
      function()
        local ws = hl.get_active_workspace()
        if not ws or ws.id < 1 then return end
        local order = ${lib.generators.toLua { multiline = false; } layouts}
        local index = 1
        for i, name in ipairs(order) do
          if name == ws.tiled_layout then index = i end
        end
        local layout = order[((index - 1 + ${toString step}) % #order) + 1]
        if layout == ws.tiled_layout then return end
        -- One selector per workspace: Hyprland's replaceOrAdd merges a rule
        -- into the enabled rule with the same workspace string, so repeated
        -- presses update that rule instead of adding new ones.
        hl.workspace_rule({ workspace = tostring(ws.id), layout = layout })
        hl.exec_cmd("notify-send -t 1500 -h string:x-canonical-private-synchronous:marchyo-layout 'Layout' '" .. layout .. "'")
      end'';

  # send_shortcut can leave the synthetic key held, so press and release it
  # as two key states.
  sendKeyLua = mods: key: ''
    hl.dispatch(hl.dsp.send_key_state({ mods = ${luaStr mods}, key = ${luaStr key}, state = "down" }))
      hl.timer(function()
        hl.dispatch(hl.dsp.send_key_state({ mods = ${luaStr mods}, key = ${luaStr key}, state = "up" }))
      end, { timeout = 50, type = "oneshot" })'';
  sendKey =
    mods: key:
    mkLuaInline ''
      function()
        ${sendKeyLua mods key}
      end'';
  # Ctrl+Shift+<key> in a terminal (windows tagged `terminal` by
  # modules/home/keybinds.nix). Every other window gets `fallback`, the
  # Insert-key chord, which Emacs and GTK/Qt apps read as copy or paste
  # without Ctrl+C/V meaning anything else there.
  universalClipboard =
    key: fallback:
    mkLuaInline ''
      function()
        local window = hl.get_active_window()
        local terminal = false
        for _, tag in ipairs((window and window.tags) or {}) do
          if tag:gsub("%*$", "") == "terminal" then terminal = true end
        end
        if terminal then
          ${sendKeyLua "CTRL SHIFT" key}
        else
          hl.dispatch(hl.dsp.${fallback})
        end
      end'';
  insertCopy = ''send_shortcut({ mods = "CTRL", key = "Insert" })'';
  insertPaste = ''send_shortcut({ mods = "SHIFT", key = "Insert" })'';
in
ctx:
let
  inherit (ctx) cli;
  shellVerb = args: "${cli} shell ${args}";

  wsAction = expr: mkLuaInline "marchyoWorkspaces.${expr}";
  wsNext = if ctx.perMonitor then "m+1" else "e+1";
  wsPrev = if ctx.perMonitor then "m-1" else "e-1";
  wsFormer = if ctx.perMonitor then "previous_per_monitor" else "previous";
  moveWorkspaceToMonitor =
    dir:
    if ctx.perMonitor then
      wsAction "move_to_monitor(${luaStr dir})"
    else
      dsp "workspace.move({ monitor = ${luaStr dir} })";

  app = entry "Apps";
  win = entry "Windows";
  ws = entry "Workspaces";
  mon = entry "Monitors";
  group = entry "Groups";
  panel = entry "Panels";
  menu = entry "Menus";
  notif = entry "Notifications";
  capture = entry "Capture";
  clip = entry "Clipboard";
  toggle = entry "Toggles";
  util = entry "Utilities";
  media = entry "Media";
  session = entry "Session";
  dictation = entry "Dictation";
  emacs = entry "Emacs";
  webapp = entry "Web apps";

  lockKeyOpts = {
    release = true;
    non_consuming = true;
    ignore_mods = true;
    locked = true;
  };
  levelOpts = {
    locked = true;
    repeating = true;
  };

  # Super+1..0, Super+Shift+1..0 and Super+Shift+Alt+1..0 act on slot n of the
  # focused monitor's block.
  perMonitorWorkspaceBinds = lib.concatMap (
    n:
    let
      key = "code:${toString (n + 9)}";
      s = toString n;
    in
    [
      (ws "SUPER + ${key}" "Switch to workspace ${s}" (wsAction "focus(${s})"))
      (ws "SUPER + SHIFT + ${key}" "Move window to workspace ${s}" (wsAction "move_window(${s})"))
      (ws "SUPER + SHIFT + ALT + ${key}" "Move window silently to workspace ${s}" (
        wsAction "move_window(${s}, false)"
      ))
    ]
  ) (lib.range 1 10);

  globalWorkspaceBinds =
    map (
      n:
      ws "SUPER + SHIFT + code:${toString (n + 9)}" "Move window to workspace ${toString n}" (
        dsp "window.move({ workspace = ${toString n} })"
      )
    ) (lib.range 1 10)
    ++ map (
      n:
      ws "SUPER + SHIFT + ALT + code:${toString (n + 9)}"
        "Move window silently to workspace ${toString n}"
        (dsp "window.move({ workspace = ${toString n}, follow = false })")
    ) (lib.range 1 10)
    ++ map (
      n:
      ws "SUPER + ${toString n}" "Switch to workspace ${toString n}" (
        dsp "focus({ workspace = ${toString n}, on_current_monitor = true })"
      )
    ) (lib.range 1 5);

  volumeCommands =
    if ctx.shell then
      {
        XF86AudioRaiseVolume = [
          "Volume up"
          "${cli} volume up"
        ];
        XF86AudioLowerVolume = [
          "Volume down"
          "${cli} volume down"
        ];
        XF86AudioMute = [
          "Mute"
          "${cli} volume mute"
        ];
        XF86AudioMicMute = [
          "Mute microphone"
          "${cli} volume mute --mic"
        ];
        XF86MonBrightnessUp = [
          "Brightness up"
          "${cli} brightness up"
        ];
        XF86MonBrightnessDown = [
          "Brightness down"
          "${cli} brightness down"
        ];
      }
    else
      {
        XF86AudioRaiseVolume = [
          "Volume up"
          "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
        ];
        XF86AudioLowerVolume = [
          "Volume down"
          "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ];
        XF86AudioMute = [
          "Mute"
          "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ];
        XF86AudioMicMute = [
          "Mute microphone"
          "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ];
        XF86MonBrightnessUp = [
          "Brightness up"
          "brightnessctl -e4 -n2 set 5%+"
        ];
        XF86MonBrightnessDown = [
          "Brightness down"
          "brightnessctl -e4 -n2 set 5%-"
        ];
      };

  mediaCommands = {
    XF86AudioNext = [
      "Next track"
      "playerctl next"
    ];
    XF86AudioPause = [
      "Play or pause"
      "playerctl play-pause"
    ];
    XF86AudioPlay = [
      "Play or pause"
      "playerctl play-pause"
    ];
    XF86AudioPrev = [
      "Previous track"
      "playerctl previous"
    ];
  };

  kbd = verb: exec "${cli} brightness --keyboard ${verb}";

  windmove =
    action: dir: exec "${ctx.commands.emacsWindmove or "marchyo-cross-windmove"} ${action} ${dir}";
in
[
  (app "SUPER + return" "Terminal" (execLua "terminal"))
  (moved "SUPER + F" (app "SUPER + SHIFT + F" "File manager" (execLua "fileManager")))
  (moved "SUPER + B" (app "SUPER + SHIFT + B" "Web browser" (execLua "browser")))
  (moved "SUPER + M" (app "SUPER + SHIFT + M" "Music player" (execLua "music")))
  (newBind (app "SUPER + SHIFT + Q" "Calculator" (execInTerminal "qalc")))
  (newBind (app "SUPER + SHIFT + T" "Activity (btop)" (execInTerminalAs "org.omarchy.btop" "btop")))
  (app "SUPER + E" "Editor" (execLua "editor"))
  (app "SUPER + O" "Obsidian" (execLua "notes"))
  (moved "SUPER + G" (app "SUPER + SHIFT + G" "Messenger" (execLua "messenger")))
  # Focus the running 1Password window if there is one, otherwise launch it.
  # The class regex covers both spellings the app reports.
  (app "SUPER + slash" "Password manager" (mkLuaInline ''
    function()
      local wins = hl.get_windows({ class = "^(1[pP]assword)$" })
      if #wins > 0 then
        hl.dispatch(hl.dsp.focus({ window = wins[1] }))
      else
        hl.dispatch(hl.dsp.exec_cmd(passwordManager))
      end
    end''))
  (app "SUPER + SHIFT + I" "Input method config" (exec "fcitx5-configtool"))
  (capture "SUPER + SHIFT + C" "Pick color (hex to clipboard)" (exec "marchyo capture color"))
  (toggle "SUPER + SHIFT + L" "Cycle theme" (exec "marchyo theme next"))
  (win "SUPER + W" "Close active window" (dsp "window.close()"))
  (win "SUPER + Q" "Close active window" (dsp "window.close()"))
  (win "SUPER + J" "Toggle split" (dsp "layout(\"togglesplit\")"))
  (win "SUPER + P" "Pseudo window" (dsp "window.pseudo()"))
  (win "SUPER + T" "Toggle floating" (dsp "window.float({ action = \"toggle\" })"))
  (newBind (clip "SUPER + A" "Select all" (sendKey "CTRL" "A")))
  (newBind (clip "SUPER + C" "Universal copy" (universalClipboard "C" insertCopy)))
  (newBind (clip "SUPER + V" "Universal paste" (universalClipboard "V" insertPaste)))
  # CTRL+Insert / SHIFT+Insert copy and paste in terminals too, where CTRL+C is SIGINT.
  (legacyOnly (clip "SUPER + C" "Copy" (dsp insertCopy)))
  (legacyOnly (clip "SUPER + V" "Paste" (dsp insertPaste)))
  (clip "SUPER + X" "Cut" (dsp "send_shortcut({ mods = \"CTRL\", key = \"X\" })"))
  (win "SUPER + left" "Move focus left" (dsp "focus({ direction = \"l\" })"))
  (win "SUPER + right" "Move focus right" (dsp "focus({ direction = \"r\" })"))
  (win "SUPER + up" "Move focus up" (dsp "focus({ direction = \"u\" })"))
  (win "SUPER + down" "Move focus down" (dsp "focus({ direction = \"d\" })"))
  (newBind (win "SUPER + L" "Cycle workspace layout" (cycleLayout 1)))
  (newBind (win "SUPER + ALT + L" "Cycle workspace layout back" (cycleLayout (-1))))
  (newBind (
    win "SUPER + M" "Minimize window to the drawer" (
      dsp "window.move({ workspace = \"special:magic\", follow = false })"
    )
  ))
]
++ onlyIf ctx.perMonitor perMonitorWorkspaceBinds
++ onlyIf (!ctx.perMonitor) globalWorkspaceBinds
++ [
  (ws "SUPER + TAB" "Next workspace" (dsp "focus({ workspace = \"${wsNext}\" })"))
  (ws "SUPER + SHIFT + TAB" "Previous workspace" (dsp "focus({ workspace = \"${wsPrev}\" })"))
  (ws "SUPER + CTRL + TAB" "Former workspace" (dsp "focus({ workspace = \"${wsFormer}\" })"))
  (win "SUPER + SHIFT + left" "Swap window to the left" (dsp "window.swap({ direction = \"l\" })"))
  (win "SUPER + SHIFT + right" "Swap window to the right" (dsp "window.swap({ direction = \"r\" })"))
  (win "SUPER + SHIFT + up" "Swap window up" (dsp "window.swap({ direction = \"u\" })"))
  (win "SUPER + SHIFT + down" "Swap window down" (dsp "window.swap({ direction = \"d\" })"))
  # Hyprland runs every bind on a chord in order: cycle, then raise.
  (win "ALT + Tab" "Cycle to next window" (dsp "window.cycle_next()"))
  (win "ALT + SHIFT + Tab" "Cycle to prev window" (dsp "window.cycle_next({ next = false })"))
  (win "ALT + Tab" "Reveal active window on top" (dsp "window.alter_zorder({ mode = \"top\" })"))
  (win "ALT + SHIFT + Tab" "Reveal active window on top" (
    dsp "window.alter_zorder({ mode = \"top\" })"
  ))
  (ws "SUPER + mouse_down" "Scroll active workspace forward" (
    dsp "focus({ workspace = \"${wsNext}\" })"
  ))
  (ws "SUPER + mouse_up" "Scroll active workspace backward" (
    dsp "focus({ workspace = \"${wsPrev}\" })"
  ))

  (group "SUPER + ALT + G" "Toggle window grouping" (dsp "group.toggle()"))
  (group "SUPER + ALT + SHIFT + G" "Move window out of group" (
    dsp "window.move({ out_of_group = true })"
  ))
  (group "SUPER + ALT + left" "Move window into group on left" (
    dsp "window.move({ into_group = \"l\" })"
  ))
  (group "SUPER + ALT + right" "Move window into group on right" (
    dsp "window.move({ into_group = \"r\" })"
  ))
  (group "SUPER + ALT + up" "Move window into group above" (
    dsp "window.move({ into_group = \"u\" })"
  ))
  (group "SUPER + ALT + down" "Move window into group below" (
    dsp "window.move({ into_group = \"d\" })"
  ))
  (group "SUPER + ALT + TAB" "Next window in group" (dsp "group.next()"))
  (group "SUPER + ALT + SHIFT + TAB" "Previous window in group" (dsp "group.prev()"))

  # Descriptions name the edge that moves; a negative delta shrinks.
  (win "SUPER + minus" "Shrink window left" (
    dsp "window.resize({ x = -100, y = 0, relative = true })"
  ))
  (win "SUPER + equal" "Expand window right" (
    dsp "window.resize({ x = 100, y = 0, relative = true })"
  ))
  (win "SUPER + SHIFT + minus" "Shrink window up" (
    dsp "window.resize({ x = 0, y = -100, relative = true })"
  ))
  (win "SUPER + SHIFT + equal" "Expand window down" (
    dsp "window.resize({ x = 0, y = 100, relative = true })"
  ))

  (win "SUPER + CTRL + F" "Tiled full screen" (
    dsp "window.fullscreen_state({ internal = 0, client = 2 })"
  ))
  (win "SUPER + ALT + F" "Full width" (dsp "window.fullscreen({ mode = \"maximized\" })"))

  (mon "SUPER + SHIFT + ALT + left" "Move workspace to left monitor" (moveWorkspaceToMonitor "l"))
  (mon "SUPER + SHIFT + ALT + right" "Move workspace to right monitor" (moveWorkspaceToMonitor "r"))
  (mon "SUPER + SHIFT + ALT + up" "Move workspace to monitor above" (moveWorkspaceToMonitor "u"))
  (mon "SUPER + SHIFT + ALT + down" "Move workspace to monitor below" (moveWorkspaceToMonitor "d"))

  (mon "CTRL + ALT + TAB" "Focus next monitor" (dsp "focus({ monitor = \"+1\" })"))
  (mon "CTRL + ALT + SHIFT + TAB" "Focus previous monitor" (dsp "focus({ monitor = \"-1\" })"))

  (util "SUPER + CTRL + Z" "Zoom in" (exec "marchyo zoom in"))
  (util "SUPER + CTRL + SHIFT + Z" "Zoom out" (exec "marchyo zoom out"))
  (util "SUPER + CTRL + ALT + Z" "Reset zoom" (exec "marchyo zoom reset"))

  (legacyOnly (toggle "SUPER + CTRL + N" "Toggle nightlight" (exec "marchyo toggle nightlight")))
  (toggle "SUPER + CTRL + I" "Toggle idle lock" (exec "marchyo toggle idle"))
  (toggle "SUPER + CTRL + K" "Toggle caffeine (keep awake)" (exec "marchyo toggle caffeine"))
  (capture "SUPER + ALT + Print" "Toggle screen recording" (exec "marchyo capture record"))

  (win "SUPER + Page_Up" "Full screen" (dsp "window.fullscreen({ mode = \"fullscreen\" })"))
  # The drawer is the `magic` special workspace; Super+M minimizes into it.
  (ws "SUPER + D" "Toggle the drawer" (dsp "workspace.toggle_special(\"magic\")"))
  (ws "SUPER + SHIFT + D" "Move window to the drawer" (
    dsp "window.move({ workspace = \"special:magic\" })"
  ))
  # The unified shell engages its in-shell WlSessionLock; otherwise hyprlock.
  (moved "SUPER + L" (
    session "SUPER + CTRL + L" "Lock the screen" (
      exec (if ctx.shell then shellVerb "lock" else "hyprlock")
    )
  ))
  (session "CTRL + ALT + Delete" "Shut down" (exec "systemctl poweroff"))
  (legacyOnly (
    mon "SUPER + SHIFT + comma" "Move window to previous monitor" (
      dsp "window.move({ monitor = \"-1\" })"
    )
  ))
  (legacyOnly (
    mon "SUPER + SHIFT + period" "Move window to next monitor" (dsp "window.move({ monitor = \"+1\" })")
  ))
  (newBind (
    mon "SUPER + SHIFT + CTRL + left" "Move window to left monitor" (
      dsp "window.move({ monitor = \"l\" })"
    )
  ))
  (newBind (
    mon "SUPER + SHIFT + CTRL + right" "Move window to right monitor" (
      dsp "window.move({ monitor = \"r\" })"
    )
  ))
  (newBind (
    mon "SUPER + SHIFT + CTRL + up" "Move window to monitor above" (
      dsp "window.move({ monitor = \"u\" })"
    )
  ))
  (newBind (
    mon "SUPER + SHIFT + CTRL + down" "Move window to monitor below" (
      dsp "window.move({ monitor = \"d\" })"
    )
  ))

  (withOpts { mouse = true; } (win "SUPER + mouse:272" "Move window" (dsp "window.drag()")))
  (withOpts { mouse = true; } (win "SUPER + mouse:273" "Resize window" (dsp "window.resize()")))
]
# Volume and brightness keys. With the shell on, the CLI changes the level
# silently and the shell OSD shows it. `locked` keeps them working over the
# lock screen, `repeating` allows hold.
++ lib.mapAttrsToList (
  key: v: withOpts levelOpts (hidden (media key (builtins.head v) (exec (lib.last v))))
) volumeCommands
++ onlyIf ctx.kbdBacklight (
  map (withOpts levelOpts) [
    (hidden (media "XF86KbdBrightnessUp" "Keyboard backlight up" (kbd "up")))
    (hidden (media "XF86KbdBrightnessDown" "Keyboard backlight down" (kbd "down")))
    (hidden (media "CTRL + XF86MonBrightnessUp" "Keyboard backlight up" (kbd "up")))
    (hidden (media "CTRL + XF86MonBrightnessDown" "Keyboard backlight down" (kbd "down")))
  ]
  ++ [
    (withOpts { locked = true; } (
      hidden (media "XF86KbdLightOnOff" "Toggle keyboard backlight" (kbd "toggle"))
    ))
  ]
)
++ lib.mapAttrsToList (
  key: v: withOpts { locked = true; } (hidden (media key (builtins.head v) (exec (lib.last v))))
) mediaCommands
++ onlyIf (ctx.dictation.enabled && ctx.dictation.toggleKey != null) [
  (dictation ctx.dictation.toggleKey "Dictation toggle" (exec "${cli} dictation toggle"))
]
++ onlyIf ctx.dictation.hold [
  (dictation ctx.dictation.holdKey "Dictation push-to-talk (hold)" (exec "${cli} dictation start"))
  (withOpts
    {
      release = true;
      non_consuming = true;
      ignore_mods = true;
    }
    (dictation ctx.dictation.holdKey "Dictation push-to-talk (release)" (exec "${cli} dictation stop"))
  )
]
++ onlyIf ctx.dictation.statusWindow [
  (dictation "SUPER + SHIFT + H" "Dictation status" (
    execLua ''terminal .. " --class=org.omarchy.voxtype -e voxtype status --follow"''
  ))
]
# The lock-key binds pass the key through and only tell the shell to re-read
# the Caps Lock / Num Lock LEDs.
++ onlyIf ctx.shell [
  (withOpts lockKeyOpts (hidden (session "Caps_Lock" "Refresh Caps Lock state" (global "lockKeys"))))
  (withOpts lockKeyOpts (hidden (session "Num_Lock" "Refresh Num Lock state" (global "lockKeys"))))
  (moved "SUPER + SHIFT + V" (panel "SUPER + CTRL + A" "Audio panel" (global "panel.audio")))
  (moved "SUPER + SHIFT + N" (panel "SUPER + CTRL + N" "Network panel" (global "panel.network")))
  (moved "SUPER + SHIFT + B" (panel "SUPER + CTRL + P" "Power panel" (global "panel.power")))
  (newBind (panel "SUPER + CTRL + D" "Display panel" (global "panel.display")))
  (moved "SUPER + SHIFT + M" (
    panel "SUPER + CTRL + M" "System monitor panel" (global "panel.monitor")
  ))
  (moved "SUPER + SHIFT + Q" (
    panel "SUPER + CTRL + O" "Control Center" (global "panel.controlcenter")
  ))
  (panel "SUPER + CTRL + ALT + E" "World clock" (global "panel.elsewhen"))
  (newBind (panel "SUPER + CTRL + U" "What's new" (global "panel.whatsnew")))
  (newBind (panel "SUPER + CTRL + H" "First-login setup checklist" (global "panel.setup")))
  (newBind (panel "SUPER + CTRL + ALT + G" "Ui gallery (developer)" (global "panel.gallery")))
  (moved "SUPER + grave" (panel "SUPER + CTRL + grave" "Window overview" (global "overview")))
  (panel "SUPER + CTRL + T" "Theme picker" (global "panel.themes"))
  (newBind (panel "SUPER + CTRL + SHIFT + W" "Wallpaper picker" (global "panel.backgrounds")))
  (panel "SUPER + CTRL + B" "Bluetooth panel" (global "panel.bluetooth"))
  (newBind (
    panel "SUPER + CTRL + SHIFT + B" "Bluetooth manager" (execInTerminalAs "org.omarchy.bluetui" "bluetui")
  ))
  (newBind (panel "SUPER + CTRL + ALT + P" "Speed test" (global "panel.speedtest")))
  (newBind (panel "SUPER + CTRL + ALT + D" "Dropbox panel" (global "panel.dropbox")))
  (panel "SUPER + SHIFT + SPACE" "Toggle top bar" (global "bar"))
]
++ onlyIf (ctx.launcher && ctx.shell) [
  (clip "SUPER + CTRL + V" "Clipboard history" (global "launcher.clipboard"))
  (moved "SUPER + period" (menu "SUPER + CTRL + E" "Emoji picker" (global "launcher.emoji")))
  (menu "SUPER + R" "App launcher" (global "launcher.apps"))
]

# Monitor controls, connectivity TUIs and extra launchers. With the shell on,
# Super+Ctrl+A and Super+Ctrl+N open its audio and network panels instead of
# the TUIs.
++ [
  # SUPER+/ (slash) is the password manager, so the scale cycle sits on the
  # adjacent backslash.
  (mon "SUPER + backslash" "Cycle monitor scale" (exec "marchyo monitor scale-cycle"))
  (mon "SUPER + CTRL + Delete" "Toggle laptop display" (exec "marchyo monitor laptop-toggle"))
  # Lid switch: hide the internal panel while an external display is on.
  (withOpts { locked = true; } (
    hidden (mon "switch:on:Lid Switch" "Lid closed" (exec "marchyo monitor clamshell on"))
  ))
  (withOpts { locked = true; } (
    hidden (mon "switch:off:Lid Switch" "Lid opened" (exec "marchyo monitor clamshell off"))
  ))
  (legacyOnly (
    panel "SUPER + CTRL + A" "Audio mixer" (execInTerminalAs "org.omarchy.wiremix" "wiremix")
  ))
  (legacyOnly (
    panel "SUPER + CTRL + W" "Wi-Fi manager" (execInTerminalAs "org.omarchy.nmtui" "nmtui")
  ))
  (newBind (toggle "SUPER + CTRL + W" "Next background" (exec "marchyo bg next")))
  (app "SUPER + ALT + return" "tmux Work session" (execInPlainTerminal "tmux new -A -s Work"))
  (app "SUPER + ALT + SHIFT + F" "File manager at terminal cwd" (exec "marchyo launch file-manager"))
]
++ onlyIf (!ctx.shell) [
  (panel "SUPER + CTRL + B" "Bluetooth manager" (execInTerminalAs "org.omarchy.bluetui" "bluetui"))
  (newBind (
    panel "SUPER + CTRL + A" "Audio mixer" (execInTerminalAs "org.omarchy.wiremix" "wiremix")
  ))
  (newBind (
    panel "SUPER + CTRL + N" "Network manager" (execInTerminalAs "org.omarchy.nmtui" "nmtui")
  ))
]

# Window utilities and the shell's notification actions.
++ [
  (win "SUPER + ALT + O" "Pop window out (float, pin, centre)" (exec "marchyo window pop"))
  (newBind (
    win "SUPER + CTRL + ALT + F" "Toggle full screen desktop" (exec "marchyo toggle fullscreen-desktop")
  ))
]
++ onlyIf ctx.shell [
  (newBind (
    notif "SUPER + comma" "Dismiss, invoke or focus the newest notification" (
      global "notifications.act"
    )
  ))
  (newBind (
    notif "SUPER + ALT + comma" "Dismiss the newest notification" (global "notifications.dismissOne")
  ))
  (newBind (
    notif "SUPER + CTRL + comma" "Control notifications with the keyboard" (
      global "notifications.keyboard"
    )
  ))
  (newBind (
    notif "SUPER + CTRL + ALT + comma" "Silence notifications (do-not-disturb)" (
      global "notifications.silence"
    )
  ))
  (moved "SUPER + CTRL + SHIFT + comma" (
    notif "SUPER + SHIFT + comma" "Dismiss all notifications" (global "notifications.dismissAll")
  ))
  (moved "SUPER + N" (
    notif "SUPER + SHIFT + ALT + comma" "Notification history" (global "panel.notifications")
  ))
  (legacyOnly (notif "SUPER + comma" "Dismiss last notification" (global "notifications.dismiss")))
  (legacyOnly (notif "SUPER + CTRL + comma" "Toggle do-not-disturb" (global "dnd")))
  (legacyOnly (
    notif "SUPER + ALT + comma" "Control notifications with the keyboard" (
      global "notifications.keyboard"
    )
  ))
]

++ onlyIf (ctx.cheatsheet && ctx.launcher && ctx.shell) [
  (session "SUPER + K" "Keybindings cheat sheet" (global "launcher.keys"))
]
++ onlyIf (ctx.cheatsheet && !(ctx.launcher && ctx.shell)) [
  (session "SUPER + K" "Keybindings cheat sheet" (execInTerminal "marchyo keybindings"))
]

# The command menu (Launcher/MenuProvider). Super+Space opens its root, and the
# per-route chords open one level directly; Super+Alt+Space opens the apps.
++ onlyIf (ctx.launcher && ctx.shell) [
  (newBind (menu "SUPER + ALT + SPACE" "App launcher" (global "launcher.apps")))
]
++ onlyIf (ctx.menus && ctx.launcher && ctx.shell) [
  (menu "SUPER + Escape" "System menu (lock, suspend, restart, shut down)" (global "menu.system"))
  (moved "SUPER + ALT + SPACE" (menu "SUPER + SPACE" "Command menu" (global "menu")))
  (newBind (menu "SUPER + CTRL + C" "Capture menu" (global "menu.capture")))
  (newBind (menu "SUPER + CTRL + X" "Toggle menu" (global "menu.toggle")))
  (newBind (menu "SUPER + CTRL + SHIFT + H" "Hardware menu" (global "menu.hardware")))
  (newBind (menu "SUPER + CTRL + SHIFT + T" "Theme menu" (global "menu.theme")))
]

++ onlyIf (ctx.menus && !(ctx.launcher && ctx.shell)) [
  (menu "SUPER + Escape" "System menu (lock, suspend, restart, shut down)" (
    execInTerminal "marchyo menu power"
  ))
  (menu "SUPER + ALT + Space" "Marchyo menu" (execInTerminal "marchyo menu"))
]

# Keyboard binds trigger cursor.hide_on_key_press, so captures stay cursor-free.
++ onlyIf ctx.screenshot.enable (
  [
    (capture "Print" "Screenshot area/window" (exec "marchyo capture screenshot"))
    (capture "SUPER + S" "Screenshot area/window" (exec "marchyo capture screenshot"))
    (newBind (
      capture "SUPER + CTRL + ALT + C" "Screenshot area/window" (exec "marchyo capture screenshot")
    ))
    (capture "SHIFT + Print" "Screenshot active window" (
      exec "marchyo capture screenshot --target active"
    ))
    (capture "SUPER + CTRL + S" "Screenshot active window" (
      exec "marchyo capture screenshot --target active"
    ))
    (capture "CTRL + Print" "Screenshot current screen" (
      exec "marchyo capture screenshot --target output"
    ))
    (capture "SUPER + ALT + S" "Screenshot current screen" (
      exec "marchyo capture screenshot --target output"
    ))
    (capture "ALT + Print" "Screenshot all screens" (exec "marchyo capture screenshot --target screen"))
    (capture "SUPER + CTRL + ALT + S" "Screenshot all screens" (
      exec "marchyo capture screenshot --target screen"
    ))
  ]
  ++ onlyIf ctx.screenshot.annotation [
    (capture "SUPER + SHIFT + Print" "Screenshot with annotation" (
      exec "marchyo capture screenshot --edit"
    ))
    (capture "SUPER + SHIFT + S" "Screenshot with annotation" (
      exec "marchyo capture screenshot --edit"
    ))
  ]
  ++ onlyIf ctx.screenshot.ocr [
    (capture "SUPER + SHIFT + O" "OCR region to clipboard" (exec "marchyo capture ocr"))
    (capture "SUPER + CTRL + SHIFT + S" "OCR region to clipboard" (exec "marchyo capture ocr"))
  ]
)

# Interactive commands run in the floating terminal; notify commands run directly.
++ onlyIf ctx.reminders [
  (util "SUPER + CTRL + R" "Set reminder" (execInTerminal "marchyo reminder set"))
  (util "SUPER + CTRL + ALT + R" "Show reminders" (execInTerminal "marchyo reminder show"))
  (util "SUPER + CTRL + SHIFT + R" "Clear reminders" (exec "marchyo reminder clear"))
]
++ onlyIf ctx.utilities [
  (util "SUPER + CTRL + ALT + T" "Show date and time" (exec "marchyo info datetime"))
  (util "SUPER + CTRL + ALT + B" "Show battery status" (exec "marchyo info battery"))
  (util "SUPER + CTRL + period" "Transcode media" (execInTerminal "marchyo transcode"))
]

++ onlyIf ctx.emacs.enable [
  (emacs "SUPER + SHIFT + E" "New Emacs frame" (exec "emacsclient -c -n"))
]
# Super+Ctrl+Alt: Super+L and Super+Alt+L cycle layouts.
++ onlyIf ctx.emacs.windmove [
  (moved "SUPER + ALT + H" (
    emacs "SUPER + CTRL + ALT + H" "Focus window (Emacs-aware) left" (windmove "focus" "l")
  ))
  (moved "SUPER + ALT + L" (
    emacs "SUPER + CTRL + ALT + L" "Focus window (Emacs-aware) right" (windmove "focus" "r")
  ))
  (moved "SUPER + ALT + K" (
    emacs "SUPER + CTRL + ALT + K" "Focus window (Emacs-aware) up" (windmove "focus" "u")
  ))
  (moved "SUPER + ALT + J" (
    emacs "SUPER + CTRL + ALT + J" "Focus window (Emacs-aware) down" (windmove "focus" "d")
  ))
  (moved "SUPER + ALT + SHIFT + H" (
    emacs "SUPER + CTRL + ALT + SHIFT + H" "Swap window (Emacs-aware) left" (windmove "move" "l")
  ))
  (moved "SUPER + ALT + SHIFT + L" (
    emacs "SUPER + CTRL + ALT + SHIFT + L" "Swap window (Emacs-aware) right" (windmove "move" "r")
  ))
  (moved "SUPER + ALT + SHIFT + K" (
    emacs "SUPER + CTRL + ALT + SHIFT + K" "Swap window (Emacs-aware) up" (windmove "move" "u")
  ))
  (moved "SUPER + ALT + SHIFT + J" (
    emacs "SUPER + CTRL + ALT + SHIFT + J" "Swap window (Emacs-aware) down" (windmove "move" "d")
  ))
]
++ onlyIf ctx.emacs.scratchpad [
  (emacs "SUPER + Z" "Emacs scratchpad" (
    exec (ctx.commands.emacsScratchpad or "marchyo-emacs-scratchpad")
  ))
]
++ onlyIf ctx.emacs.everywhere [
  (moved "SUPER + CTRL + E" (
    emacs "SUPER + SHIFT + ALT + E" "Emacs everywhere" (exec "emacsclient -ne '(emacs-everywhere)'")
  ))
]
++ onlyIf ctx.emacs.orgProtocol [
  (moved "SUPER + SHIFT + T" (
    emacs "SUPER + CTRL + ALT + O" "Org capture (task)" (exec "emacsclient -c -n -e '(org-capture)'")
  ))
]

# marchyo.webapps apps that declare a key.
++ map (a: webapp a.combo a.name (exec a.command)) ctx.webapps

# Quake-style console (special:qconsole) and the herdr agent workspace manager.
# Options live in modules/nixos/options/ai-tools.nix, packages in
# modules/nixos/ai-tools.nix.
{
  config,
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  hlua = import ../../lib/hyprland-lua.nix { inherit lib; };
  marchyoCfg = osConfig.marchyo or { };
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  desktopEnabled = isLinux && (marchyoCfg.desktop.enable or false);
  consoleEnabled = desktopEnabled && (marchyoCfg.console.enable or true);
  herdrCfg = (marchyoCfg.ai or { }).herdr or { };
  herdrEnabled = desktopEnabled && (herdrCfg.enable or false);
  reduceMotion = (marchyoCfg.theme.appearance or { }).reduceMotion or false;

  hyprSettings = config.wayland.windowManager.hyprland.settings;
  terminal = hyprSettings.terminal._var;

  consoleClass = "org.marchyo.console";

  # $AI_AGENT is set by modules/nixos/ai-agent.nix; a shell otherwise.
  seedCommand = "${terminal} --class=${consoleClass} -e sh -c 'exec \${AI_AGENT:-\${SHELL:-sh}}'";

  consoleLua = ''
    local CONSOLE = "special:qconsole"
    local share = 0.5
    local box = 2

    hl.on("workspace.created", function(ws)
      if ws and ws.name == CONSOLE and ws.is_empty then
        hl.exec_cmd(${hlua.luaStr seedCommand}, { workspace = CONSOLE .. " silent" })
      end
    end)

    hl.config({ decoration = { dim_special = 0.6 } })

    local beside, below = nil, nil

    local function cover(side, bottom)
      if beside == side and below == bottom then
        return false
      end
      beside, below = side, bottom
      hl.workspace_rule({
        workspace = CONSOLE,
        gaps_in = 0,
        gaps_out = { top = 0, right = side, bottom = bottom, left = side },
        no_border = true,
      })
      return true
    end

    local function alone()
      local tiled = 0
      for _, window in ipairs(hl.get_workspace_windows(CONSOLE)) do
        if not window.floating then
          tiled = tiled + 1
        end
      end
      return tiled <= 1
    end

    local function fit(monitor)
      if not monitor or not monitor.scale or monitor.scale <= 0 then
        return false
      end
      local width, height = monitor.width, monitor.height
      if monitor.transform % 2 == 1 then
        width, height = height, width
      end
      local reserved = monitor.reserved
      height = height / monitor.scale - reserved.top - reserved.bottom
      width = width / monitor.scale - reserved.left - reserved.right
      local tall = math.floor(height * share)
      local wide = width
      if alone() then
        wide = math.min(width, tall * box)
      end
      return cover(math.floor((width - wide) / 2), math.floor(height - tall))
    end

    local function console_monitor()
      local ws = hl.get_workspace(CONSOLE)
      local mon = ws and ws.visible and ws.monitor
      if mon and mon.scale and mon.scale > 0 then
        return mon
      end
      return hl.get_active_monitor()
    end

    local function refit(monitor)
      if fit(monitor or console_monitor()) then
        hl.exec_scheduled_prop_refresh_immediately()
      end
    end

    cover(0, 0)
    fit(console_monitor())

    hl.on("monitor.layout_changed", function() refit() end)
    hl.on("monitor.focused", function() refit() end)
    hl.on("workspace.special_active", function(ws, mon)
      if ws and ws.name == CONSOLE then refit(mon) end
    end)
    hl.on("workspace.move_to_monitor", function(ws, mon)
      if ws and ws.name == CONSOLE then refit(mon) end
    end)

    local function recount()
      local ws = hl.get_workspace(CONSOLE)
      if ws and ws.visible then refit() end
    end
    hl.on("window.open", recount)
    hl.on("window.destroy", recount)
    hl.on("window.move_to_workspace", recount)
    hl.on("window.update_rules", recount)
  ''
  + lib.optionalString (!reduceMotion) ''

    hl.curve("qconsoleEase", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
    hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 3, bezier = "qconsoleEase", style = "slide top" })
    hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 2, bezier = "qconsoleEase", style = "slide bottom" })
  '';

  # herdr integrations: installed agent package name -> herdr target and the
  # config directory herdr installs into (it only writes into one that exists).
  agentTargets = {
    claude-code = {
      target = "claude";
      dir = ''"''${CLAUDE_CONFIG_DIR:-$HOME/.claude}"'';
    };
    codex = {
      target = "codex";
      dir = ''"''${CODEX_HOME:-$HOME/.codex}"'';
    };
    opencode = {
      target = "opencode";
      dir = ''"''${XDG_CONFIG_HOME:-$HOME/.config}/opencode"'';
    };
    pi = {
      target = "pi";
      dir = ''"$HOME/.pi/agent"'';
    };
    grok = {
      target = "grok";
      dir = ''"''${GROK_HOME:-$HOME/.grok}"'';
    };
  };

  installedNames = map lib.getName (
    (osConfig.environment.systemPackages or [ ]) ++ config.home.packages
  );
  installedAgents = lib.filterAttrs (name: _: lib.elem name installedNames) agentTargets;

  herdr = lib.getExe pkgs.herdr;

  integrationService =
    _: agent:
    let
      script = pkgs.writeShellScript "herdr-integration-${agent.target}" ''
        mkdir -p ${agent.dir} && ${herdr} integration install ${agent.target} >/dev/null
      '';
    in
    lib.nameValuePair "herdr-integration-${agent.target}" {
      Unit = {
        Description = "herdr integration for ${agent.target}";
        After = [ "herdr-server.service" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${script}";
      };
      Install.WantedBy = [ "default.target" ];
    };
in
{
  config = lib.mkMerge [
    (lib.mkIf consoleEnabled {
      wayland.windowManager.hyprland = {
        extraConfig = consoleLua;
        settings = {
          window_rule = [
            {
              match.class = "^${lib.replaceStrings [ "." ] [ "\\." ] consoleClass}$";
              workspace = "special:qconsole silent";
            }
          ];
        };
      };
    })

    (lib.mkIf herdrEnabled {
      systemd.user.services = {
        herdr-server = {
          Unit.Description = "herdr server";
          Service = {
            ExecStart = "${herdr} server";
            Restart = "on-failure";
          };
          Install.WantedBy = [ "default.target" ];
        };
      }
      // lib.mapAttrs' integrationService installedAgents;
    })
  ];
}

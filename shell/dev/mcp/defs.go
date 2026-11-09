package main

func obj(props map[string]any, required ...string) map[string]any {
	s := map[string]any{"type": "object", "properties": props}
	if len(required) > 0 {
		s["required"] = required
	}
	return s
}

func str(desc string) map[string]any {
	return map[string]any{"type": "string", "description": desc}
}

func strs(desc string) map[string]any {
	return map[string]any{
		"type": "array", "items": map[string]any{"type": "string"}, "description": desc,
	}
}

func boolean(desc string) map[string]any {
	return map[string]any{"type": "boolean", "description": desc}
}

func (s *server) definitions() []tool {
	empty := obj(map[string]any{})
	return []tool{
		{"sandbox_up", "Start the isolated shell sandbox (nested Hyprland).", obj(map[string]any{
			"fixture": str("fixture name under dev/fixtures (default: default)"),
			"real":    boolean("also bind the real system bus and PipeWire"),
			"window":  boolean("keep the nested window visible instead of parking it"),
		}), longTimeout, s.up},
		{"sandbox_down", "Stop the sandbox and remove its runtime dir.", empty,
			shortTimeout, s.simple("sandbox", "down")},
		{"sandbox_status", "Report whether the sandbox is running.", empty, shortTimeout, s.status},
		{"ipc_call", "Call a shell IPC function in the sandbox, e.g. target=shell " +
			"function=openLauncher args=[apps]. Returns the call's stdout.", obj(map[string]any{
			"target":   str("IPC target, e.g. shell"),
			"function": str("function name on the target"),
			"args":     strs("positional arguments"),
		}, "target", "function"), shortTimeout, s.ipcCall},
		{"ipc_show", "List the shell IPC targets and their functions.", empty,
			shortTimeout, s.simple("sandbox", "ipc", "show")},
		{"screenshot", "Screenshot one shell surface in the sandbox (starts it when down). " +
			"Returns the PNG and any new QML warnings.", obj(map[string]any{
			"surface": str("launcher[:MODE], menu[:ROUTE], panel:ID, overview, screen, or a " +
				"registered surface name opened by ipc"),
			"state":   strs("state settings as key=value, e.g. query=fire, select=2"),
			"ipc":     strs("IPC calls to run before the shot, each 'TARGET FUNCTION ARGS'"),
			"grab":    boolean("capture the card alone, with alpha"),
			"fixture": str("fixture name used when the sandbox must start"),
		}, "surface"), longTimeout, s.screenshot},
		{"logs", "Return the last lines of the sandbox log, without ANSI colors.", obj(map[string]any{
			"lines": map[string]any{
				"type": "integer", "minimum": 1, "description": "number of lines (default 200)",
			},
		}), shortTimeout, s.logs},
		{"reload", "Reload the shell in the sandbox (ipc call shell reload).", empty,
			shortTimeout, s.simple("sandbox", "ipc", "call", "shell", "reload")},
	}
}

import {
  type Runtime,
  captureArgv,
  err,
  hyprctlDispatchArgv,
  hyprlandAvailable,
  luaString,
  usageError,
  tr,
} from "@marchyo/core";

// Window utilities driven through Hyprland's Lua dispatchers. `exec` is an
// injection seam for tests; it defaults to a quiet hyprctl run.
export type Dispatch = (lua: string) => Promise<number>;

export const WINDOW_ACTIONS = ["pop", "close-all", "tiled-fullscreen"] as const;
export type WindowAction = (typeof WINDOW_ACTIONS)[number];

const POP_WIDTH = 1300;
const POP_HEIGHT = 900;

async function defaultDispatch(lua: string): Promise<number> {
  const r = await captureArgv(hyprctlDispatchArgv(lua));
  return r.code;
}

type ActiveWindow = {
  address?: string;
  pinned?: boolean;
  fullscreenClient?: number;
};

async function activeWindow(): Promise<ActiveWindow | null> {
  const r = await captureArgv(["hyprctl", "activewindow", "-j"]);
  if (r.code !== 0) return null;
  try {
    const parsed = JSON.parse(r.stdout) as ActiveWindow;
    return parsed.address ? parsed : null;
  } catch {
    return null;
  }
}

// Lua dispatchers that pop a tiled window out (float, size, centre, pin, raise,
// tag "pop") or put a popped window back.
export function popLua(address: string, pinned: boolean): string[] {
  const w = `{ window = ${luaString(`address:${address}`)}`;
  const win = (extra: string) => `hl.dsp.window.${extra}`;
  if (pinned) {
    return [
      win(`pin(${w} })`),
      win(`float(${w}, action = "toggle" })`),
      win(`tag(${w}, tag = "-pop" })`),
    ];
  }
  return [
    win(`float(${w}, action = "toggle" })`),
    win(`resize(${w}, x = ${POP_WIDTH}, y = ${POP_HEIGHT} })`),
    win(`center(${w} })`),
    win(`pin(${w} })`),
    win(`alter_zorder(${w}, mode = "top" })`),
    win(`tag(${w}, tag = "+pop" })`),
  ];
}

export function tiledFullscreenLua(fullscreenClient: number): string {
  const client = fullscreenClient === 2 ? 0 : 2;
  return `hl.dsp.window.fullscreen_state({ internal = 0, client = ${client} })`;
}

export function closeLua(address: string): string {
  return `hl.dsp.window.close({ window = ${luaString(`address:${address}`)} })`;
}

async function runAll(dispatch: Dispatch, lua: string[]): Promise<number> {
  for (const l of lua) {
    const code = await dispatch(l);
    if (code !== 0) return code;
  }
  return 0;
}

async function closeAll(dispatch: Dispatch): Promise<number> {
  const r = await captureArgv(["hyprctl", "clients", "-j"]);
  if (r.code !== 0) return 1;
  let clients: Array<{ address?: string }> = [];
  try {
    clients = JSON.parse(r.stdout) as Array<{ address?: string }>;
  } catch {
    return 1;
  }
  for (const c of clients) {
    if (c.address) await dispatch(closeLua(c.address));
  }
  return dispatch('hl.dsp.focus({ workspace = 1 })');
}

export async function runWindow(
  rt: Runtime,
  action: string,
  dispatch: Dispatch = defaultDispatch,
): Promise<number> {
  if (!(WINDOW_ACTIONS as readonly string[]).includes(action)) {
    return usageError(
      rt,
      tr("window.unknownWindowAction", action),
      `marchyo window <${WINDOW_ACTIONS.join("|")}>`,
    );
  }
  if (!hyprlandAvailable()) {
    err(rt, tr("launch.notInsideHyprlandSession"));
    return 1;
  }
  if (action === "close-all") return closeAll(dispatch);
  const win = await activeWindow();
  if (!win?.address) return 0;
  const code =
    action === "pop"
      ? await runAll(dispatch, popLua(win.address, win.pinned === true))
      : await dispatch(tiledFullscreenLua(win.fullscreenClient ?? 0));
  if (code !== 0) err(rt, tr("window.windowFailed", action));
  return code;
}

import {
  type Runtime,
  ShellIpcError,
  data,
  err,
  hint,
  shellIpc,
  usageError,
} from "@marchyo/core";

// `marchyo shell …`: the verbs over the running shell's IpcHandler. Each verb
// names its shell.qml function as a literal so the contract test can match
// every call against shell.qml.

const ID_RE = /^[a-z][a-z0-9-]*$/;

// Report a failed shell call: 1 for every kind, with a next step for the two
// a user can act on.
export function reportShellIpcError(rt: Runtime, e: unknown): number {
  if (!(e instanceof ShellIpcError)) throw e;
  err(rt, e.message);
  if (e.kind === "not-running") {
    hint(rt, "Try: systemctl --user start marchyo-shell");
  } else if (e.kind === "not-installed") {
    hint(rt, "The shell is enabled with marchyo.shell.enable = true");
  }
  return 1;
}

async function call(
  rt: Runtime,
  invoke: () => Promise<string>,
  fn: string,
): Promise<number> {
  let reply: string;
  try {
    reply = await invoke();
  } catch (e) {
    return reportShellIpcError(rt, e);
  }
  data(rt, { function: fn, reply }, () => reply);
  return 0;
}

export async function runShellPanel(
  rt: Runtime,
  action: string,
  panel: string | undefined,
): Promise<number> {
  if (action === "close" && panel === undefined) {
    return call(rt, () => shellIpc("closePanels"), "closePanels");
  }
  if (panel === undefined || !ID_RE.test(panel)) {
    return usageError(
      rt,
      panel === undefined ? "missing panel id" : `invalid panel id: "${panel}"`,
      `marchyo shell ${action} audio`,
    );
  }
  if (action === "toggle") {
    return call(rt, () => shellIpc("togglePanel", panel), "togglePanel");
  }
  if (action === "close") {
    return call(rt, () => shellIpc("closePanel", panel), "closePanel");
  }
  return call(rt, () => shellIpc("openPanel", panel), "openPanel");
}

export async function runShellLauncher(
  rt: Runtime,
  mode: string,
): Promise<number> {
  if (!ID_RE.test(mode)) {
    return usageError(
      rt,
      `invalid launcher mode: "${mode}"`,
      "marchyo shell launcher apps|emoji|clipboard",
    );
  }
  return call(rt, () => shellIpc("toggleLauncher", mode), "toggleLauncher");
}

export async function runShellBar(
  rt: Runtime,
  state: string | undefined,
): Promise<number> {
  if (state === undefined) {
    return call(rt, () => shellIpc("toggleBar"), "toggleBar");
  }
  if (state !== "on" && state !== "off") {
    return usageError(rt, `invalid bar state: "${state}"`, "marchyo shell bar on|off");
  }
  return call(rt, () => shellIpc("setBar", state), "setBar");
}

export async function runShellOverview(
  rt: Runtime,
  state: string | undefined,
): Promise<number> {
  if (state === undefined) {
    return call(rt, () => shellIpc("toggleOverview"), "toggleOverview");
  }
  if (state === "on") {
    return call(rt, () => shellIpc("openOverview"), "openOverview");
  }
  if (state === "off") {
    return call(rt, () => shellIpc("closeOverview"), "closeOverview");
  }
  return usageError(rt, `invalid overview state: "${state}"`, "marchyo shell overview on|off");
}

export async function runShellReload(rt: Runtime): Promise<number> {
  return call(rt, () => shellIpc("reload"), "reload");
}

export async function runShellLock(rt: Runtime): Promise<number> {
  return call(rt, () => shellIpc("lock"), "lock");
}

export async function runShellLockState(rt: Runtime): Promise<number> {
  return call(rt, () => shellIpc("lockState"), "lockState");
}

export async function runShellDismiss(
  rt: Runtime,
  all: boolean,
): Promise<number> {
  if (all) {
    return call(rt, () => shellIpc("clearNotifications"), "clearNotifications");
  }
  return call(rt, () => shellIpc("dismissLast"), "dismissLast");
}

export async function runShellDnd(
  rt: Runtime,
  state: string | undefined,
): Promise<number> {
  if (state === undefined) {
    return call(rt, () => shellIpc("toggleDnd"), "toggleDnd");
  }
  if (state !== "on" && state !== "off") {
    return usageError(rt, `invalid dnd state: "${state}"`, "marchyo shell dnd on|off");
  }
  return call(rt, () => shellIpc("setDnd", state), "setDnd");
}

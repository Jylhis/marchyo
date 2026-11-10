import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import {
  DEFAULT_PORTAL_URI,
  type PortalDeps,
  type Runtime,
  acquireLock,
  captureArgv,
  commandAvailable,
  err,
  hint,
  hyprctlDispatchArgv,
  info,
  luaString,
  notifySendArgv,
  parseExitNode,
  portalWindowClass,
  runArgv,
  runPortalFlow,
  usageError,
  tr,
} from "@marchyo/core";

// `marchyo network …`. The `portal` verb signs in to a captive portal: it
// pauses a Tailscale exit node, opens the check URI in a chromium app window,
// waits for NetworkManager to report full connectivity, then closes the window
// and restores the exit node. The config file comes from
// modules/home/captive-portal.nix.

const BROWSERS = ["brave", "google-chrome", "chromium"];

type PortalConfig = { uri: string; browser: string | null };

function configPath(): string {
  const base = process.env.XDG_CONFIG_HOME || join(homedir(), ".config");
  return join(base, "marchyo", "captive-portal.json");
}

function lockPath(): string {
  const base = process.env.XDG_RUNTIME_DIR || `/run/user/${process.getuid?.() ?? 0}`;
  return join(base, "marchyo-network-portal.lock");
}

function readConfig(): PortalConfig {
  try {
    const raw = JSON.parse(readFileSync(configPath(), "utf8")) as Record<
      string,
      unknown
    >;
    return {
      uri: typeof raw.uri === "string" ? raw.uri : DEFAULT_PORTAL_URI,
      browser: typeof raw.browser === "string" ? raw.browser : null,
    };
  } catch {
    return { uri: DEFAULT_PORTAL_URI, browser: null };
  }
}

function resolveBrowser(configured: string | null): string | null {
  if (configured && commandAvailable(configured)) return configured;
  return BROWSERS.find(commandAvailable) ?? null;
}

async function nmConnectivity(): Promise<string> {
  const r = await Promise.race([
    captureArgv(["nmcli", "networking", "connectivity", "check"]),
    new Promise<{ code: number; stdout: string }>((resolve) =>
      setTimeout(() => resolve({ code: 124, stdout: "" }), 5_000),
    ),
  ]);
  return r.code === 0 ? r.stdout.trim().toLowerCase() : "";
}

type Launcher = { failed(): boolean };

function launch(argv: string[]): Launcher {
  let status: number | null = null;
  try {
    const proc = Bun.spawn(argv, {
      stdout: "ignore",
      stderr: "ignore",
      stdin: "ignore",
    });
    void proc.exited.then((code) => {
      status = code;
    });
  } catch {
    status = 127;
  }
  return { failed: () => status !== null && status !== 0 };
}

// The browser handoff can return before the window maps, so an online check
// that wins the race still waits a moment for the window to appear.
async function closeByClass(cls: string, sleep: (ms: number) => Promise<void>) {
  let seen = false;
  for (let i = 0; i < 20; i++) {
    const clients = await captureArgv(["hyprctl", "clients", "-j"]);
    let present = false;
    try {
      const list = JSON.parse(clients.stdout) as { class?: string }[];
      present = list.some((c) => new RegExp(cls).test(c.class ?? ""));
    } catch {
      present = false;
    }
    if (present) {
      seen = true;
      await runArgv(
        hyprctlDispatchArgv(
          `hl.dsp.window.close({ window = ${luaString(`class:${cls}`)} })`,
        ),
        { noInput: true },
      );
    } else if (seen) {
      return;
    }
    await sleep(300);
  }
}

function buildDeps(uri: string, browser: string): PortalDeps {
  const cls = portalWindowClass(uri);
  let launcher: Launcher | null = null;
  const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));
  return {
    now: () => Date.now(),
    sleep,
    checkConnectivity: nmConnectivity,
    windowFailed: () => launcher?.failed() ?? false,
    openWindow: () => {
      launcher = launch([browser, `--app=${uri}`]);
    },
    closeWindow: async () => {
      if (cls) await closeByClass(cls, sleep);
    },
    activeExitNode: async () => {
      if (!commandAvailable("tailscale")) return null;
      const r = await captureArgv(["tailscale", "status", "--json"]);
      return r.code === 0 ? parseExitNode(r.stdout) : null;
    },
    setExitNode: async (peer) =>
      (await runArgv(["tailscale", "set", `--exit-node=${peer}`], {
        noInput: true,
      })) === 0,
    notify: (summary, body) => {
      void runArgv(notifySendArgv(summary, body), { noInput: true }).catch(
        () => 0,
      );
    },
  };
}

export async function runNetworkPortal(
  rt: Runtime,
  opts: { uri?: string; browser?: string },
): Promise<number> {
  const cfg = readConfig();
  const uri = opts.uri ?? cfg.uri;
  const browser = resolveBrowser(opts.browser ?? cfg.browser);
  if (!/^https?:\/\//.test(uri)) {
    return usageError(rt, tr("network.notAnHttpUrl", uri), "marchyo network portal --uri http://…");
  }
  if (!browser) {
    err(rt, tr("network.noChromiumFamilyBrowserFound"));
    hint(rt, tr("network.enableMarchyoWebappsOrInstall"));
    return 1;
  }
  const deps = buildDeps(uri, browser);
  const release = acquireLock(lockPath());
  if (!release) {
    // An earlier run holds the exit-node pause and watches for the sign-in;
    // this one only brings the window back.
    deps.openWindow();
    info(rt, tr("network.signInAlreadyInProgress"));
    return 0;
  }
  try {
    info(rt, tr("network.openingWaitingForTheNetwork", uri));
    const result = await runPortalFlow(deps);
    if (result === "window-failed") {
      err(rt, tr("network.failedToOpenTheSign", browser));
      return 1;
    }
    return 0;
  } finally {
    release();
  }
}

import { mkdirSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";

// Captive-portal sign-in flow behind `marchyo network portal`. The state
// machine takes its side effects as `PortalDeps`, so it runs under test with a
// fake clock and no processes.

export const DEFAULT_PORTAL_URI =
  "http://nmcheck.gnome.org/check_network_status.txt";

export const FAST_POLL_MS = 2_000;
export const FAST_WINDOW_MS = 300_000;
export const SLOW_POLL_MS = 15_000;

// Hyprland class of a chromium `--app=<uri>` window: `chrome-<host>__<path>`
// (brave-… for Brave). Dots become `[.]` so the pattern survives Lua quoting.
export function portalWindowClass(uri: string): string | null {
  const m = /^[a-zA-Z][a-zA-Z0-9+.-]*:\/\/([^/:?#]+)/.exec(uri);
  if (!m) return null;
  return `^(chrome|brave)-${m[1]!.replaceAll(".", "[.]")}__.*$`;
}

// The peer to restore after the sign-in: first Tailscale IP of the active exit
// node in `tailscale status --json`, or null when no exit node is in use.
export function parseExitNode(statusJson: string): string | null {
  let status: unknown;
  try {
    status = JSON.parse(statusJson);
  } catch {
    return null;
  }
  const node = (status as { ExitNodeStatus?: unknown } | null)?.ExitNodeStatus;
  if (node === null || typeof node !== "object") return null;
  const ips = (node as { TailscaleIPs?: unknown }).TailscaleIPs;
  if (!Array.isArray(ips)) return null;
  const first = ips.find((ip): ip is string => typeof ip === "string");
  return first ? first.replace(/\/\d+$/, "") : null;
}

export type PortalDeps = {
  now(): number;
  sleep(ms: number): Promise<void>;
  // `nmcli networking connectivity check`, trimmed; "" on failure or timeout.
  checkConnectivity(): Promise<string>;
  // True when the browser launcher exited with an error.
  windowFailed(): boolean;
  openWindow(): void;
  closeWindow(): Promise<void>;
  // Exit-node peer to restore, or null when none is active.
  activeExitNode(): Promise<string | null>;
  setExitNode(peer: string): Promise<boolean>;
  notify(summary: string, body?: string): void;
};

export type PortalResult = "online" | "window-failed";

// Poll every 2s for the first 5 minutes, then every 15s, until NetworkManager
// reports `full`. Joining another working network also ends the wait.
export async function waitUntilOnline(
  deps: Pick<
    PortalDeps,
    "now" | "sleep" | "checkConnectivity" | "windowFailed"
  >,
): Promise<PortalResult> {
  const fastUntil = deps.now() + FAST_WINDOW_MS;
  while ((await deps.checkConnectivity()) !== "full") {
    if (deps.windowFailed()) return "window-failed";
    await deps.sleep(deps.now() < fastUntil ? FAST_POLL_MS : SLOW_POLL_MS);
  }
  return "online";
}

// An exit node routes the sign-in page into a tunnel the portal still blocks,
// so it is cleared first and always restored.
export async function runPortalFlow(deps: PortalDeps): Promise<PortalResult> {
  const peer = await deps.activeExitNode();
  const paused = peer !== null && (await deps.setExitNode(""));
  if (paused) {
    deps.notify("Tailscale exit node paused", "Paused for captive-portal sign-in");
  }
  try {
    deps.openWindow();
    const result = await waitUntilOnline(deps);
    if (result === "online") await deps.closeWindow();
    return result;
  } finally {
    if (paused && peer !== null) {
      if (await deps.setExitNode(peer)) {
        deps.notify("Tailscale exit node restored");
      } else {
        deps.notify(
          "Tailscale exit node not restored",
          `Run: tailscale set --exit-node=${peer}`,
        );
      }
    }
  }
}

// Single-instance lock: a pid file. A live holder keeps it; a dead holder's
// file is replaced. Returns a release function, or null when another run holds it.
export function acquireLock(
  path: string,
  isAlive: (pid: number) => boolean = pidAlive,
): (() => void) | null {
  mkdirSync(dirname(path), { recursive: true });
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      writeFileSync(path, String(process.pid), { flag: "wx" });
      return () => {
        try {
          unlinkSync(path);
        } catch {
          // already gone
        }
      };
    } catch {
      const holder = Number.parseInt(readLockPid(path), 10);
      if (Number.isInteger(holder) && isAlive(holder)) return null;
      try {
        unlinkSync(path);
      } catch {
        // lost the race to another cleaner; retry
      }
    }
  }
  return null;
}

function readLockPid(path: string): string {
  try {
    return readFileSync(path, "utf8").trim();
  } catch {
    return "";
  }
}

function pidAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch (e) {
    return (e as NodeJS.ErrnoException).code === "EPERM";
  }
}

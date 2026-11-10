import { expect, test } from "bun:test";
import { existsSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  type PortalDeps,
  acquireLock,
  parseExitNode,
  portalWindowClass,
  runPortalFlow,
  waitUntilOnline,
} from "../src/captive-portal.ts";

function fakeDeps(answers: string[], over: Partial<PortalDeps> = {}) {
  let clock = 0;
  const sleeps: number[] = [];
  const log: string[] = [];
  let i = 0;
  const deps: PortalDeps = {
    now: () => clock,
    sleep: async (ms) => {
      sleeps.push(ms);
      clock += ms;
    },
    checkConnectivity: async () => answers[Math.min(i++, answers.length - 1)]!,
    windowFailed: () => false,
    openWindow: () => log.push("open"),
    closeWindow: async () => {
      log.push("close");
    },
    activeExitNode: async () => null,
    setExitNode: async (peer) => {
      log.push(`exit:${peer}`);
      return true;
    },
    notify: (s) => log.push(`notify:${s}`),
    ...over,
  };
  return { deps, sleeps, log };
}

test("portalWindowClass escapes dots and names the host", () => {
  expect(portalWindowClass("http://nmcheck.gnome.org/check_network_status.txt")).toBe(
    "^(chrome|brave)-nmcheck[.]gnome[.]org__.*$",
  );
  expect(portalWindowClass("http://10.0.0.1:8080/x")).toBe(
    "^(chrome|brave)-10[.]0[.]0[.]1__.*$",
  );
  expect(portalWindowClass("nonsense")).toBeNull();
  // A host with regex syntax never becomes a pattern.
  expect(portalWindowClass("http://a|.*/x")).toBeNull();
  expect(portalWindowClass("http://(a+)+b/")).toBeNull();
});

test("parseExitNode returns the first IP without a prefix length", () => {
  const json = JSON.stringify({
    ExitNodeStatus: { ID: "n1", TailscaleIPs: ["100.64.0.7/32", "fd7a::7/128"] },
  });
  expect(parseExitNode(json)).toBe("100.64.0.7");
  expect(parseExitNode(JSON.stringify({ ExitNodeStatus: null }))).toBeNull();
  expect(parseExitNode("{}")).toBeNull();
  expect(parseExitNode("not json")).toBeNull();
});

test("waitUntilOnline polls every 2s for 5 minutes, then every 15s", async () => {
  const answers = [...Array(160).fill("portal"), "full"];
  const { deps, sleeps } = fakeDeps(answers);
  expect(await waitUntilOnline(deps)).toBe("online");
  expect(sleeps.slice(0, 150).every((ms) => ms === 2_000)).toBe(true);
  expect(sleeps.slice(150).every((ms) => ms === 15_000)).toBe(true);
  expect(sleeps).toHaveLength(160);
});

test("waitUntilOnline stops when the browser launcher failed", async () => {
  const { deps } = fakeDeps(["portal"], { windowFailed: () => true });
  expect(await waitUntilOnline(deps)).toBe("window-failed");
});

test("runPortalFlow opens, waits, closes; no exit node means no tailscale calls", async () => {
  const { deps, log } = fakeDeps(["portal", "limited", "full"]);
  expect(await runPortalFlow(deps)).toBe("online");
  expect(log).toEqual(["open", "close"]);
});

test("runPortalFlow pauses the exit node and restores it after sign-in", async () => {
  const { deps, log } = fakeDeps(["portal", "full"], {
    activeExitNode: async () => "100.64.0.7",
  });
  expect(await runPortalFlow(deps)).toBe("online");
  expect(log).toEqual([
    "exit:",
    "notify:Tailscale exit node paused",
    "open",
    "close",
    "exit:100.64.0.7",
    "notify:Tailscale exit node restored",
  ]);
});

test("runPortalFlow restores the exit node when the window fails", async () => {
  const { deps, log } = fakeDeps(["portal"], {
    activeExitNode: async () => "100.64.0.7",
    windowFailed: () => true,
  });
  expect(await runPortalFlow(deps)).toBe("window-failed");
  expect(log).not.toContain("close");
  expect(log).toContain("exit:100.64.0.7");
});

test("runPortalFlow does not restore a node it failed to pause", async () => {
  const calls: string[] = [];
  const { deps } = fakeDeps(["full"], {
    activeExitNode: async () => "100.64.0.7",
    setExitNode: async (peer) => {
      calls.push(peer);
      return false;
    },
  });
  await runPortalFlow(deps);
  expect(calls).toEqual([""]);
});

test("acquireLock is exclusive, replaces a stale holder, and releases", () => {
  const dir = mkdtempSync(join(tmpdir(), "portal-lock-"));
  try {
    const path = join(dir, "sub", "portal.lock");
    const release = acquireLock(path);
    expect(release).not.toBeNull();
    expect(acquireLock(path)).toBeNull();
    release!();
    expect(existsSync(path)).toBe(false);

    writeFileSync(join(dir, "stale.lock"), "999999");
    const again = acquireLock(join(dir, "stale.lock"), () => false);
    expect(again).not.toBeNull();
    again!();
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

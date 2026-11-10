import { expect, test } from "bun:test";
import { existsSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { recorderArgv, recordingMarkerPath } from "../src/commands/capture.ts";
import {
  SESSION_EXIT_ENV,
  closeWindowDispatch,
  parseClients,
  sessionExitPlan,
  sessionExitUnitArgv,
} from "../src/commands/power.ts";
import { nightlightOnFrom } from "../src/toggles.ts";

test("night light reports the temperature hyprsunset reached", () => {
  expect(nightlightOnFrom({ code: 0, stdout: "4000\n" })).toBe(true);
  expect(nightlightOnFrom({ code: 0, stdout: "temperature: 6500" })).toBe(false);
  expect(nightlightOnFrom({ code: 1, stdout: "socket /run/user/1000/hypr/x 4000" })).toBe(false);
  expect(nightlightOnFrom({ code: 0, stdout: "" })).toBe(false);
});

test("session exits run in a bounded transient user unit", () => {
  const argv = sessionExitUnitArgv("logout", ["/bin/marchyo"]);
  expect(argv.slice(0, 2)).toEqual(["systemd-run", "--user"]);
  expect(argv).toContain("--property=RuntimeMaxSec=30s");
  expect(argv).toContain(`--setenv=${SESSION_EXIT_ENV}=1`);
  expect(argv).toContain("--setenv=HYPRLAND_INSTANCE_SIGNATURE");
  expect(argv.slice(argv.indexOf("--") + 1)).toEqual(["/bin/marchyo", "logout"]);
});

test("shutdown holds a sleep, idle and lid-switch inhibitor", () => {
  const argv = sessionExitUnitArgv("shutdown", ["/bin/marchyo"]);
  const cmd = argv.slice(argv.indexOf("--") + 1);
  expect(cmd[0]).toBe("systemd-inhibit");
  expect(cmd).toContain("--what=sleep:idle:handle-lid-switch");
  expect(cmd.slice(-2)).toEqual(["/bin/marchyo", "shutdown"]);
  const reboot = sessionExitUnitArgv("reboot", ["bun", "cli.tsx"]);
  expect(reboot.slice(reboot.indexOf("--") + 1)).toEqual(["bun", "cli.tsx", "reboot"]);
});

test("parseClients keeps valid addresses and unique positive pids", () => {
  const json = JSON.stringify([
    { address: "0x55aa", pid: 42 },
    { address: "0x66bb", pid: 42 },
    { address: '0x1" }) hl.exec_cmd("x', pid: 7 },
    { address: "0x77cc", pid: -1 },
    { pid: process.pid },
  ]);
  expect(parseClients(json)).toEqual({ addresses: ["0x55aa", "0x66bb", "0x77cc"], pids: [42, 7] });
  expect(parseClients("nope")).toEqual({ addresses: [], pids: [] });
  expect(parseClients("{}")).toEqual({ addresses: [], pids: [] });
});

test("closeWindowDispatch targets one window by address", () => {
  expect(closeWindowDispatch("0x55aa")).toBe('hl.dsp.window.close({ window = "address:0x55aa" })');
});

test("recordingMarkerPath lives under XDG_RUNTIME_DIR", () => {
  expect(recordingMarkerPath({ XDG_RUNTIME_DIR: "/run/user/1" })).toBe(
    "/run/user/1/marchyo/recording",
  );
  expect(recordingMarkerPath({})).toBeNull();
});

test("the recorder supervisor holds the marker exactly while the recorder runs", async () => {
  const dir = mkdtempSync(join(tmpdir(), "marchyo-record-"));
  const marker = join(dir, "recording");
  const argv = recorderArgv(["sleep", "0.3"], marker);
  expect(argv.join(" ")).not.toContain("gpu-screen-recorder");
  const proc = Bun.spawn(argv, {
    env: { ...process.env, MARCHYO_RECORDER: "sleep" },
    stdout: "ignore",
    stderr: "ignore",
  });
  await Bun.sleep(100);
  expect(existsSync(marker)).toBe(true);
  await proc.exited;
  expect(existsSync(marker)).toBe(false);
});

test("a stop signal reaches the recorder, which finalizes before the marker goes", async () => {
  const dir = mkdtempSync(join(tmpdir(), "marchyo-record-"));
  const marker = join(dir, "recording");
  const done = join(dir, "finalized");
  // Stand-in recorder: on SIGINT it takes 300 ms to "finalize", then exits.
  const standIn = `trap 'sleep 0.3; : > "${done}"; exit 0' INT; while :; do sleep 0.05; done`;
  const proc = Bun.spawn(recorderArgv(["sh", "-c", standIn], marker), {
    env: { ...process.env, MARCHYO_RECORDER: "sh" },
    stdout: "ignore",
    stderr: "ignore",
  });
  await Bun.sleep(200);
  expect(existsSync(marker)).toBe(true);
  proc.kill("SIGINT");
  await Bun.sleep(100);
  expect(existsSync(marker)).toBe(true);
  expect(existsSync(done)).toBe(false);
  expect(await proc.exited).toBe(0);
  expect(existsSync(done)).toBe(true);
  expect(existsSync(marker)).toBe(false);
});

test("sessionExitPlan never closes windows outside the unit", () => {
  expect(sessionExitPlan({ [SESSION_EXIT_ENV]: "1" }, true, true)).toBe("worker");
  expect(sessionExitPlan({ [SESSION_EXIT_ENV]: "1" }, false, true)).toBe("direct");
  expect(sessionExitPlan({}, true, true)).toBe("handoff");
  expect(sessionExitPlan({}, true, false)).toBe("direct");
  expect(sessionExitPlan({}, false, true)).toBe("direct");
});

test("the marker goes when the recorder dies", async () => {
  const dir = mkdtempSync(join(tmpdir(), "marchyo-record-"));
  const marker = join(dir, "recording");
  const proc = Bun.spawn(recorderArgv(["-c", "kill -SEGV $$"], marker), {
    env: { ...process.env, MARCHYO_RECORDER: "sh" },
    stdout: "ignore",
    stderr: "ignore",
  });
  await proc.exited;
  expect(existsSync(marker)).toBe(false);
  expect(recorderArgv(["gpu-screen-recorder", "-w", "region"], null)).toEqual([
    "gpu-screen-recorder",
    "-w",
    "region",
  ]);
});

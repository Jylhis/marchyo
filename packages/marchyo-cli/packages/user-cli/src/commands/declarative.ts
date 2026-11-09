import { appendFile, mkdir } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import {
  type Runtime,
  type State,
  captureArgv,
  commandAvailable,
  detectFlake,
  err,
  hint,
  info,
  mergeState,
  nixosRebuild,
  ok,
  readState,
  writeState,
  usageError,
  tr,
} from "@marchyo/core";

// Declarative-only commands (no runtime leg): edit cli-state.json, then
// rebuild. Hand-written flake config always wins (the marchyoCliState
// sidecar merges at mkDefault priority).

const FEATURES = [
  "desktop",
  "development",
  "media",
  "office",
  "dictation",
  "webapps",
] as const;
type Feature = (typeof FEATURES)[number];

// SUPER+SHIFT letters already claimed by marchyo binds and the default
// webapp set (see modules/nixos/options/webapps.nix).
const TAKEN_SUPER_SHIFT_KEYS = new Set(
  "A C D E G H I O P S W X Y Z".split(" "),
);

export type DeclarativeOpts = { dryRun?: boolean };

export async function persistAndRebuild(
  rt: Runtime,
  patch: State,
  opts: DeclarativeOpts,
  describe: string,
): Promise<number> {
  const prev = await readState().catch(() => ({}) as State);
  const next = mergeState(prev, patch);
  if (opts.dryRun) {
    ok(rt, tr("declarative.dryRunStateNotWritten", describe));
    process.stdout.write(JSON.stringify(patch) + "\n");
    return 0;
  }
  let path: string;
  try {
    ({ path } = await writeState(next));
  } catch (e) {
    if (e instanceof Error && e.message.includes("EACCES")) {
      err(rt, tr("declarative.cannotWriteStateFilePermission"));
      hint(rt, "Try: sudo marchyo …");
      return 1;
    }
    throw e;
  }
  ok(rt, `${describe} → ${path}`);
  info(
    rt,
    tr("declarative.requiresTheMarchyoclistateWiringIn"),
  );
  const flake = await detectFlake();
  if (!flake) {
    err(rt, tr("declarative.noFlakeFoundLookedIn"));
    hint(rt, "Try: run from your flake directory, then `marchyo rebuild`");
    return 1;
  }
  info(rt, tr("declarative.rebuildingFrom", flake.path));
  const result = await nixosRebuild({
    flakePath: flake.path,
    noInput: rt.noInput,
  });
  if (result.kind === "unavailable") {
    err(rt, result.message);
    return 1;
  }
  return result.code;
}

function featureOrError(rt: Runtime, raw: string): Feature | null {
  if ((FEATURES as readonly string[]).includes(raw)) return raw as Feature;
  usageError(
    rt,
    tr("declarative.unknownFeature", raw),
    `marchyo install <${FEATURES.join("|")}>`,
  );
  return null;
}

export async function runInstall(
  rt: Runtime,
  rawFeature: string,
  opts: DeclarativeOpts,
): Promise<number> {
  const feature = featureOrError(rt, rawFeature);
  if (feature === null) return 2;
  return persistAndRebuild(
    rt,
    { [feature]: { enable: true } } as State,
    opts,
    `marchyo.${feature}.enable = true`,
  );
}

export async function runRemove(
  rt: Runtime,
  rawFeature: string,
  opts: DeclarativeOpts,
): Promise<number> {
  const feature = featureOrError(rt, rawFeature);
  if (feature === null) return 2;
  return persistAndRebuild(
    rt,
    { [feature]: { enable: false } } as State,
    opts,
    `marchyo.${feature}.enable = false`,
  );
}

export type WebappAddOpts = DeclarativeOpts & {
  name?: string;
  key?: string;
  modifiers?: string;
};

export async function runWebappAdd(
  rt: Runtime,
  url: string,
  opts: WebappAddOpts,
): Promise<number> {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return usageError(
      rt,
      tr("declarative.invalidUrl", url),
      "marchyo webapp add https://example.com --name Example",
    );
  }
  const name =
    opts.name ??
    parsed.hostname.replace(/^www\./, "").split(".")[0]!.replace(/^./, (c) =>
      c.toUpperCase(),
    );
  if (opts.key !== undefined) {
    const key = opts.key.toUpperCase();
    const modifiers = (opts.modifiers ?? "SUPER SHIFT").toUpperCase();
    if (modifiers === "SUPER SHIFT" && TAKEN_SUPER_SHIFT_KEYS.has(key)) {
      return usageError(
        rt,
        tr("declarative.superShiftIsAlreadyTaken", key),
        "pick a free key, or pass --modifiers 'SUPER SHIFT ALT'",
      );
    }
  }

  const prev = await readState().catch(() => ({}) as State);
  const existing = prev.webapps?.extraApps ?? [];
  if (existing.some((a) => a.name === name)) {
    err(rt, tr("declarative.webappAlreadyExists", name));
    hint(rt, "Try: marchyo webapp rm first, or pass a different --name");
    return 1;
  }
  const entry = {
    name,
    url,
    ...(opts.key !== undefined ? { key: opts.key.toUpperCase() } : {}),
    ...(opts.modifiers !== undefined ? { modifiers: opts.modifiers } : {}),
  };
  return persistAndRebuild(
    rt,
    { webapps: { extraApps: [...existing, entry] } },
    opts,
    `webapp '${name}' added (${url})`,
  );
}

export async function runWebappRm(
  rt: Runtime,
  name: string,
  opts: DeclarativeOpts,
): Promise<number> {
  const prev = await readState().catch(() => ({}) as State);
  const existing = prev.webapps?.extraApps ?? [];
  if (!existing.some((a) => a.name === name)) {
    err(rt, tr("declarative.webappIsNotCliManaged", name));
    hint(
      rt,
      tr("declarative.builtInDefaultsLiveIn"),
    );
    return 1;
  }
  return persistAndRebuild(
    rt,
    { webapps: { extraApps: existing.filter((a) => a.name !== name) } },
    opts,
    `webapp '${name}' removed`,
  );
}

// Security enrollment wraps the interactive enrollment tools; the backing
// PAM/service config is declarative (marchyo.security.*).
export async function runSecurityEnroll(
  rt: Runtime,
  method: string,
): Promise<number> {
  switch (method) {
    case "fingerprint": {
      if (!commandAvailable("fprintd-enroll")) {
        err(rt, tr("declarative.fprintdEnrollNotFound"));
        hint(rt, tr("declarative.enableMarchyoSecurityFingerprintEnable"));
        return 1;
      }
      const proc = Bun.spawn(["fprintd-enroll"], {
        stdout: "inherit",
        stderr: "inherit",
        stdin: "inherit",
      });
      return await proc.exited;
    }
    case "fido2": {
      if (!commandAvailable("pamu2fcfg")) {
        err(rt, tr("declarative.pamuFcfgNotFound"));
        hint(rt, tr("declarative.enableMarchyoSecurityFidoEnable"));
        return 1;
      }
      info(rt, tr("declarative.touchYourSecurityKeyWhen"));
      const r = await captureArgv(["pamu2fcfg"]);
      if (r.code !== 0 || r.stdout.trim() === "") {
        err(rt, tr("declarative.pamuFcfgFailedNoKey"));
        return 1;
      }
      const dir = join(homedir(), ".config", "Yubico");
      await mkdir(dir, { recursive: true });
      const keysFile = join(dir, "u2f_keys");
      await appendFile(keysFile, r.stdout.trim() + "\n");
      ok(rt, tr("declarative.credentialAppendedTo", keysFile));
      return 0;
    }
    default:
      return usageError(
        rt,
        tr("declarative.unknownMethod", method),
        "marchyo security enroll <fido2|fingerprint>",
      );
  }
}

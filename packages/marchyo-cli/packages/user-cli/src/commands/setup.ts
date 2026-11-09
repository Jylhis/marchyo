import { existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { createInterface } from "node:readline/promises";
import {
  type NotifierWait,
  type NotifyDeps,
  type Runtime,
  actionRequest,
  bakedLanguage,
  captureArgv,
  commandAvailable,
  data,
  defaultNotifierWait,
  defaultNotifyDeps,
  err,
  info,
  languageOverride,
  loadRuntimeState,
  marchyoStateDir,
  ok,
  runArgv,
  sendNotification,
  tr,
  trn,
  usageError,
  waitForNotifier,
  warn,
} from "@marchyo/core";
import { type Backend, type DictationState, bakedBackend, stateOf } from "./dictation.ts";

// `marchyo setup`: the first-login checklist. Each item is a small check over
// a SetupProbe, so tests need no real system. A skip with a clear detail
// beats a wrong todo.

export const SETUP_IDS = [
  "git",
  "ssh",
  "fido2",
  "fingerprint",
  "language",
  "keyboard",
  "theme",
  "dictation",
] as const;
export type SetupId = (typeof SETUP_IDS)[number];

export type SetupStatus = "done" | "todo" | "skip";
export type SetupFix = { label: string; argv: string[] };
export type SetupItem = {
  id: SetupId;
  title: string;
  status: SetupStatus;
  detail: string;
  fix: SetupFix | null;
};

export type FingerprintState = "enrolled" | "none" | "no-device";

export interface SetupProbe {
  env: Record<string, string | undefined>;
  available(cmd: string): boolean;
  gitConfig(key: string): Promise<string>;
  sshPublicKeys(): string[];
  sshAgentHasKeys(): Promise<boolean>;
  sshConfigNamesAgent(): boolean;
  fidoEnrolled(): boolean;
  fingerprint(): Promise<FingerprintState>;
  language(): Promise<{ override: string | null; baked: string | null }>;
  themeOverride(): Promise<string | null>;
  dictationBackend(): Backend | null;
  dictationState(backend: Backend): Promise<DictationState>;
}

// The command that runs the interactive step. The shell wraps it in its own
// terminal (Services/Setup.qml), so this stays what a person would type.
export function fixArgv(id: SetupId): string[] {
  return ["marchyo", "setup", "fix", id];
}

function item(
  id: SetupId,
  title: string,
  status: SetupStatus,
  detail: string,
  fixLabel: string | null = null,
): SetupItem {
  const fix = status === "todo" && fixLabel !== null ? { label: fixLabel, argv: fixArgv(id) } : null;
  return { id, title, status, detail, fix };
}

export async function checkGit(p: SetupProbe): Promise<SetupItem> {
  const title = tr("setup.titleGit");
  const name = await p.gitConfig("user.name");
  const email = await p.gitConfig("user.email");
  if (name !== "" && email !== "") return item("git", title, "done", `${name} <${email}>`);
  const missing = [name === "" ? "user.name" : "", email === "" ? "user.email" : ""];
  return item("git", title, "todo", tr("setup.gitMissing", missing.filter(Boolean).join(", ")), tr("setup.fixGit"));
}

export async function checkSsh(p: SetupProbe): Promise<SetupItem> {
  const title = tr("setup.titleSsh");
  const keys = p.sshPublicKeys();
  if (keys.length > 0) return item("ssh", title, "done", keys.join(", "));
  if (p.sshConfigNamesAgent()) return item("ssh", title, "done", tr("setup.sshAgentConfigured"));
  if (await p.sshAgentHasKeys()) return item("ssh", title, "done", tr("setup.sshAgentKeys"));
  return item("ssh", title, "todo", tr("setup.sshNone"), tr("setup.fixSsh"));
}

export async function checkFido2(p: SetupProbe): Promise<SetupItem> {
  const title = tr("setup.titleFido2");
  if (!p.available("pamu2fcfg")) return item("fido2", title, "skip", tr("setup.fidoNotEnabled"));
  if (p.fidoEnrolled()) return item("fido2", title, "done", tr("setup.fidoEnrolled"));
  return item("fido2", title, "todo", tr("setup.fidoNone"), tr("setup.fixFido2"));
}

export async function checkFingerprint(p: SetupProbe): Promise<SetupItem> {
  const title = tr("setup.titleFingerprint");
  if (!p.available("fprintd-enroll")) {
    return item("fingerprint", title, "skip", tr("setup.fingerprintNotEnabled"));
  }
  const state = await p.fingerprint();
  if (state === "no-device") return item("fingerprint", title, "skip", tr("setup.fingerprintNoReader"));
  if (state === "enrolled") return item("fingerprint", title, "done", tr("setup.fingerprintEnrolled"));
  return item("fingerprint", title, "todo", tr("setup.fingerprintNone"), tr("setup.fixFingerprint"));
}

export async function checkLanguage(p: SetupProbe): Promise<SetupItem> {
  const title = tr("setup.titleLanguage");
  const { override, baked } = await p.language();
  if (override !== null) return item("language", title, "done", override);
  if (baked === null) return item("language", title, "skip", tr("setup.languageNoShell"));
  if (baked !== "en") return item("language", title, "done", baked);
  return item("language", title, "todo", tr("setup.languageDefault"), tr("setup.fixLanguage"));
}

export async function checkKeyboard(_p: SetupProbe): Promise<SetupItem> {
  return item("keyboard", tr("setup.titleKeyboard"), "skip", tr("setup.keyboardDeclarative"));
}

export async function checkTheme(p: SetupProbe): Promise<SetupItem> {
  const title = tr("setup.titleTheme");
  const chosen = await p.themeOverride();
  if (chosen !== null) return item("theme", title, "done", chosen);
  return item("theme", title, "todo", tr("setup.themeDefault"), tr("setup.fixTheme"));
}

export async function checkDictation(p: SetupProbe): Promise<SetupItem> {
  const title = tr("setup.titleDictation");
  const backend = p.dictationBackend();
  if (backend === null) return item("dictation", title, "skip", tr("setup.dictationNotEnabled"));
  if (!p.available(backend)) {
    return item("dictation", title, "skip", tr("setup.dictationMissing", backend));
  }
  const state = await p.dictationState(backend);
  if (state === "stopped" || state === "unknown") {
    return item("dictation", title, "todo", tr("setup.dictationStopped", backend), tr("setup.fixDictation"));
  }
  return item("dictation", title, "done", backend);
}

const CHECKS: Record<SetupId, (p: SetupProbe) => Promise<SetupItem>> = {
  git: checkGit,
  ssh: checkSsh,
  fido2: checkFido2,
  fingerprint: checkFingerprint,
  language: checkLanguage,
  keyboard: checkKeyboard,
  theme: checkTheme,
  dictation: checkDictation,
};

export async function collectSetupItems(probe: SetupProbe = defaultProbe()): Promise<SetupItem[]> {
  return Promise.all(SETUP_IDS.map((id) => CHECKS[id](probe)));
}

function readText(path: string): string {
  try {
    return readFileSync(path, "utf8");
  } catch {
    return "";
  }
}

export function defaultProbe(
  env: Record<string, string | undefined> = process.env,
  home: string = homedir(),
): SetupProbe {
  return {
    env,
    available: commandAvailable,
    gitConfig: async (key) => (await captureArgv(["git", "config", "--global", key])).stdout.trim(),
    sshPublicKeys: () => {
      try {
        return readdirSync(join(home, ".ssh")).filter((f) => /^id_.+\.pub$/.test(f));
      } catch {
        return [];
      }
    },
    sshAgentHasKeys: async () =>
      env.SSH_AUTH_SOCK !== undefined && (await captureArgv(["ssh-add", "-l"])).code === 0,
    sshConfigNamesAgent: () => /^\s*IdentityAgent\s/im.test(readText(join(home, ".ssh", "config"))),
    fidoEnrolled: () => {
      try {
        return statSync(join(env.XDG_CONFIG_HOME || join(home, ".config"), "Yubico", "u2f_keys")).size > 0;
      } catch {
        return false;
      }
    },
    fingerprint: async () => {
      const r = await captureArgv(["fprintd-list", env.USER ?? ""]);
      if (r.code !== 0 || /no devices/i.test(r.stdout)) return "no-device";
      return /^\s*-\s*#\d+/m.test(r.stdout) ? "enrolled" : "none";
    },
    language: async () => ({ override: await languageOverride(), baked: bakedLanguage() }),
    themeOverride: async () => {
      const value = (await loadRuntimeState()).overrides["theme.selection"];
      return typeof value === "string" && value !== "" ? value : null;
    },
    dictationBackend: () => bakedBackend(),
    dictationState: (backend) =>
      stateOf(backend, {
        backend: () => backend,
        run: captureArgv,
        available: commandAvailable,
        paste: async () => {},
        lockPath: "",
        lockWaitMs: 0,
      }),
  };
}

export type SetupOpts = { done?: boolean; welcome?: boolean };

export type SetupDeps = {
  env: NodeJS.ProcessEnv;
  probe: () => SetupProbe;
  notify: NotifyDeps;
  wait: NotifierWait;
};

export function defaultSetupDeps(): SetupDeps {
  return {
    env: process.env,
    probe: () => defaultProbe(),
    notify: defaultNotifyDeps(),
    wait: defaultNotifierWait(),
  };
}

const GLYPH_WELCOME = "\u{f135}";

function flagPath(deps: SetupDeps, name: string): string {
  return join(marchyoStateDir(deps.env), name);
}

function writeFlag(path: string): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, "");
}

async function welcome(rt: Runtime, deps: SetupDeps): Promise<void> {
  if (existsSync(flagPath(deps, "setup-done")) || existsSync(flagPath(deps, "setup-welcomed"))) return;
  if (!(await waitForNotifier(deps.wait))) {
    err(rt, tr("whatsNew.noService", Math.round(deps.wait.timeoutMs / 1000)));
    return;
  }
  const todo = (await collectSetupItems(deps.probe())).filter((i) => i.status === "todo").length;
  if (todo === 0) return;
  const card = actionRequest(
    tr("setup.welcome"),
    trn("setup.todoCount", todo, todo),
    GLYPH_WELCOME,
    tr("setup.action"),
    ["marchyo", "shell", "open", "setup"],
  );
  const sent = await sendNotification(card, deps.notify);
  if (!sent.ok) {
    err(rt, tr("notify.sendFailed", sent.error ?? ""));
    return;
  }
  writeFlag(flagPath(deps, "setup-welcomed"));
}

function renderChecklist(items: SetupItem[]): string {
  const mark = { done: "[x]", todo: "[ ]", skip: "[-]" } as const;
  return items.map((i) => `${mark[i.status]} ${i.title}: ${i.detail}`).join("\n");
}

export async function runSetup(
  rt: Runtime,
  opts: SetupOpts,
  deps: SetupDeps = defaultSetupDeps(),
): Promise<number> {
  if (opts.done === true) {
    writeFlag(flagPath(deps, "setup-done"));
    ok(rt, tr("setup.markedDone"));
    return 0;
  }
  if (opts.welcome === true) {
    try {
      await welcome(rt, deps);
    } catch (e) {
      err(rt, (e as Error).message);
    }
    return 0;
  }
  const items = await collectSetupItems(deps.probe());
  const doneFlag = existsSync(flagPath(deps, "setup-done"));
  data(rt, { items, doneFlag }, () => renderChecklist(items));
  return 0;
}

export interface FixDeps {
  env: Record<string, string | undefined>;
  run: (argv: string[]) => Promise<number>;
  ask: (question: string) => Promise<string>;
  gitConfig: (key: string) => Promise<string>;
}

export function defaultFixDeps(rt: Runtime): FixDeps {
  return {
    env: process.env,
    run: (argv) => runArgv(argv, { noInput: rt.noInput }),
    ask: async (question) => {
      if (rt.noInput || !process.stdin.isTTY) return "";
      const rl = createInterface({ input: process.stdin, output: process.stderr });
      try {
        return (await rl.question(question)).trim();
      } finally {
        rl.close();
      }
    },
    gitConfig: async (key) => (await captureArgv(["git", "config", "--global", key])).stdout.trim(),
  };
}

type Step = (deps: FixDeps) => Promise<boolean>;

const run = (...argv: string[]): Step => async (d) => (await d.run(argv)) === 0;

async function gitFix(d: FixDeps): Promise<boolean> {
  let good = true;
  for (const [key, question] of [
    ["user.name", tr("setup.askGitName")],
    ["user.email", tr("setup.askGitEmail")],
  ] as const) {
    if ((await d.gitConfig(key)) !== "") continue;
    const value = await d.ask(question);
    if (value === "") {
      good = false;
      continue;
    }
    good = (await d.run(["git", "config", "--global", key, value])) === 0 && good;
  }
  return good;
}

// Lists the choices, asks for one, then applies it with `marchyo <verb> <choice>`.
function chooseFix(listArgv: string[], applyArgv: string[], question: () => string): Step {
  return async (d) => {
    await d.run(listArgv);
    const choice = await d.ask(question());
    if (choice === "") return false;
    return (await d.run([...applyArgv, choice])) === 0;
  };
}

const FIXES: Record<SetupId, Step | null> = {
  git: gitFix,
  ssh: run("ssh-keygen", "-t", "ed25519"),
  fido2: run("marchyo", "security", "enroll", "fido2"),
  fingerprint: run("marchyo", "security", "enroll", "fingerprint"),
  language: chooseFix(["marchyo", "language", "list"], ["marchyo", "language"], () => tr("setup.askLanguage")),
  keyboard: null,
  theme: chooseFix(["marchyo", "theme", "list"], ["marchyo", "theme", "set"], () => tr("setup.askTheme")),
  dictation: run("marchyo", "dictation", "start"),
};

export async function runSetupFix(
  rt: Runtime,
  id: string,
  deps: FixDeps = defaultFixDeps(rt),
): Promise<number> {
  if (!(SETUP_IDS as readonly string[]).includes(id)) {
    return usageError(rt, tr("setup.unknownItem", id), `marchyo setup fix <${SETUP_IDS.join("|")}>`);
  }
  const step = FIXES[id as SetupId];
  if (step === null) {
    info(rt, tr("setup.nothingToFix", id));
    return 0;
  }
  let good = false;
  try {
    good = await step(deps);
  } catch (e) {
    warn(rt, (e as Error).message);
  }
  if (good) ok(rt, tr("setup.fixDone", id));
  else warn(rt, tr("setup.fixIncomplete", id));
  await deps.ask(tr("setup.pressEnter"));
  return good ? 0 : 1;
}

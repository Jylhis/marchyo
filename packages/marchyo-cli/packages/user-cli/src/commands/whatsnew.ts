import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, readlinkSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  type NotifierWait,
  type NotifyDeps,
  type Runtime,
  actionRequest,
  captureArgv,
  commandAvailable,
  data,
  defaultNotifierWait,
  defaultNotifyDeps,
  err,
  info,
  listSystemGenerations,
  marchyoStateDir,
  pickDiffTargets,
  sendNotification,
  tr,
  trn,
  waitForNotifier,
} from "@marchyo/core";

// `marchyo whats-new`: what the installed NEWS gained since the user last
// looked. The shell panel reads --json; a user unit runs --notify at login.

export type WhatsNewOpts = { notify?: boolean; markSeen?: boolean };

export type WhatsNewDeps = {
  env: NodeJS.ProcessEnv;
  newsPath: () => string | null;
  notify: NotifyDeps;
  wait: NotifierWait;
  summary: () => Promise<string[]>;
};

const FRESH_ENTRY_LIMIT = 5;
const SUMMARY_LINES = 40;
const GLYPH_NEWS = "\u{f05a}";

export function newsPath(
  env: NodeJS.ProcessEnv = process.env,
  execPath: string = process.execPath,
): string | null {
  const candidates = [
    env.MARCHYO_NEWS,
    join(dirname(dirname(execPath)), "share", "marchyo", "NEWS"),
    join(dirname(fileURLToPath(import.meta.url)), "..", "..", "..", "..", "..", "..", "NEWS"),
  ];
  for (const path of candidates) {
    if (path !== undefined && path !== "" && existsSync(path)) return path;
  }
  return null;
}

// The entries of a GNU-style NEWS file: the indented paragraphs, outline
// headings dropped, whitespace normalised.
export function newsEntries(text: string): string[] {
  const entries: string[] = [];
  for (const block of text.split(/\n[ \t]*\n/)) {
    const lines = block.split("\n").filter((l) => !l.startsWith("*"));
    if (lines.length === 0 || !/^[ \t]/.test(lines[0]!)) continue;
    const entry = lines.join(" ").replace(/\s+/g, " ").trim();
    if (entry !== "") entries.push(entry);
  }
  return entries;
}

export function newEntries(news: string, baseline: string | null): string[] {
  const current = newsEntries(news);
  if (baseline === null) return current.slice(0, FRESH_ENTRY_LIMIT);
  const known = new Set(newsEntries(baseline));
  return current.filter((e) => !known.has(e));
}

function readOrNull(path: string): string | null {
  try {
    return readFileSync(path, "utf8");
  } catch {
    return null;
  }
}

function ensureDir(dir: string): void {
  mkdirSync(dir, { recursive: true });
}

function markSeen(dir: string, hash: string, news: string): void {
  ensureDir(dir);
  writeFileSync(join(dir, "seen-news"), `${hash}\n`);
  writeFileSync(join(dir, "seen-news.txt"), news);
}

function stripAnsi(text: string): string {
  return text.replace(/\u001b\][^\u0007\u001b]*(?:\u0007|\u001b\\)/g, "").replace(
    /\u001b\[[0-9;?]*[ -/]*[@-~]/g,
    "",
  );
}

export async function dixSummary(): Promise<string[]> {
  const generations = listSystemGenerations();
  if (generations.length === 0 || !commandAvailable("dix")) return [];
  let current: string | null = null;
  try {
    current = readlinkSync("/run/current-system");
  } catch {
    // not activated; fall back to the last two generations
  }
  const targets = pickDiffTargets(current, generations, "/run/current-system");
  if (targets === null) return [];
  const out = await captureArgv(["dix", "diff", targets.left, targets.right]);
  if (out.code !== 0) return [];
  const lines = stripAnsi(out.stdout).split("\n").map((l) => l.trimEnd());
  while (lines.length > 0 && lines[lines.length - 1] === "") lines.pop();
  return lines.slice(0, SUMMARY_LINES);
}

export function defaultWhatsNewDeps(): WhatsNewDeps {
  return {
    env: process.env,
    newsPath: () => newsPath(),
    notify: defaultNotifyDeps(),
    wait: defaultNotifierWait(),
    summary: dixSummary,
  };
}

type Snapshot = {
  dir: string;
  news: string;
  hash: string;
  seen: string | null;
  baseline: string | null;
};

function snapshot(deps: WhatsNewDeps): Snapshot | null {
  const path = deps.newsPath();
  const news = path === null ? null : readOrNull(path);
  if (news === null) return null;
  const dir = marchyoStateDir(deps.env);
  const seen = readOrNull(join(dir, "seen-news"))?.trim() ?? null;
  return {
    dir,
    news,
    hash: createHash("sha256").update(news).digest("hex"),
    seen: seen === "" ? null : seen,
    baseline: readOrNull(join(dir, "seen-news.txt")),
  };
}

async function notifyUpdated(rt: Runtime, deps: WhatsNewDeps): Promise<void> {
  const snap = snapshot(deps);
  if (snap === null) {
    err(rt, tr("whatsNew.noNews"));
    return;
  }
  if (snap.seen === null) {
    markSeen(snap.dir, snap.hash, snap.news);
    return;
  }
  if (snap.seen === snap.hash) return;
  const count = newEntries(snap.news, snap.baseline).length;
  if (count > 0) {
    if (!(await waitForNotifier(deps.wait))) {
      err(rt, tr("whatsNew.noService", Math.round(deps.wait.timeoutMs / 1000)));
      return;
    }
    const card = actionRequest(
      tr("whatsNew.updated"),
      trn("whatsNew.entries", count, count),
      GLYPH_NEWS,
      tr("whatsNew.action"),
      ["marchyo", "shell", "open", "whatsnew"],
    );
    const sent = await sendNotification(card, deps.notify);
    if (!sent.ok) {
      err(rt, tr("notify.sendFailed", sent.error ?? ""));
      return;
    }
  }
  ensureDir(snap.dir);
  writeFileSync(join(snap.dir, "seen-news"), `${snap.hash}\n`);
}

export async function runWhatsNew(
  rt: Runtime,
  opts: WhatsNewOpts,
  deps: WhatsNewDeps = defaultWhatsNewDeps(),
): Promise<number> {
  if (opts.notify === true) {
    try {
      await notifyUpdated(rt, deps);
    } catch (e) {
      err(rt, (e as Error).message);
    }
    return 0;
  }
  const snap = snapshot(deps);
  if (snap === null) {
    err(rt, tr("whatsNew.noNews"));
    return 1;
  }
  const entries = newEntries(snap.news, snap.baseline);
  const changed = snap.seen !== snap.hash || entries.length > 0;
  if (opts.markSeen !== true || rt.format === "json") {
    const summary = rt.format === "json" ? await deps.summary() : [];
    data(rt, { changed, hash: snap.hash, entries, summary }, () =>
      entries.length === 0 ? tr("whatsNew.nothingNew") : entries.map((e) => `- ${e}`).join("\n\n"),
    );
  }
  if (opts.markSeen === true) {
    markSeen(snap.dir, snap.hash, snap.news);
    info(rt, tr("whatsNew.marked"));
  }
  return 0;
}

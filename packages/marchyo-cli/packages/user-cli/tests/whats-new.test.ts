import { describe, expect, spyOn, test } from "bun:test";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { type Runtime, defaultNotifyDeps } from "@marchyo/core";
import {
  type WhatsNewDeps,
  newEntries,
  newsEntries,
  newsPath,
  runWhatsNew,
} from "../src/commands/whatsnew.ts";
import { fakeBusctl, useSourceCatalog } from "./fake-busctl.ts";

useSourceCatalog();

const CLI = join(import.meta.dir, "..", "src", "cli.tsx");

const NEWS_V1 = `marchyo NEWS                                -*- outline -*-

Preamble that is not an entry.

* Noteworthy changes in 2026

** New features

  First feature, which wraps
  over two lines.

  Second feature.

** Bug fixes

  A fix.
`;

const NEWS_V2 = NEWS_V1.replace(
  "** New features\n",
  "** New features\n\n  Brand new   feature.\n",
);

const sha = (text: string): string => createHash("sha256").update(text).digest("hex");

type Fixture = { news: string; state: string; fake: ReturnType<typeof fakeBusctl> };

function fixture(text = NEWS_V1): Fixture {
  const fake = fakeBusctl();
  const news = join(fake.dir, "NEWS");
  writeFileSync(news, text);
  return { news, state: join(fake.dir, "state", "marchyo"), fake };
}

async function whatsNew(f: Fixture, args: string[] = []) {
  const proc = Bun.spawn([process.execPath, CLI, "whats-new", ...args], {
    stdout: "pipe",
    stderr: "pipe",
    env: { ...process.env, NO_COLOR: "1", ...f.fake.env, MARCHYO_NEWS: f.news },
  });
  const code = await proc.exited;
  return {
    code,
    stdout: await new Response(proc.stdout).text(),
    stderr: await new Response(proc.stderr).text(),
  };
}

function seed(f: Fixture, text: string): void {
  mkdirSync(f.state, { recursive: true });
  writeFileSync(join(f.state, "seen-news"), `${sha(text)}\n`);
  writeFileSync(join(f.state, "seen-news.txt"), text);
}

describe("entries", () => {
  test("indented paragraphs, whitespace normalised, headings and preamble dropped", () => {
    expect(newsEntries(NEWS_V1)).toEqual([
      "First feature, which wraps over two lines.",
      "Second feature.",
      "A fix.",
    ]);
  });

  test("new entries versus a baseline", () => {
    expect(newEntries(NEWS_V2, NEWS_V1)).toEqual(["Brand new feature."]);
    expect(newEntries(NEWS_V1, NEWS_V1)).toEqual([]);
  });

  test("no baseline: the first five", () => {
    const many = Array.from({ length: 8 }, (_, i) => `  Entry ${i}.\n`).join("\n");
    expect(newEntries(many, null)).toEqual(["Entry 0.", "Entry 1.", "Entry 2.", "Entry 3.", "Entry 4."]);
  });

  test("the packaged NEWS parses", () => {
    const path = newsPath({}, "/nonexistent/bin/marchyo");
    expect(path).not.toBeNull();
    expect(newsEntries(readFileSync(path!, "utf8")).length).toBeGreaterThan(5);
  });

  test("MARCHYO_NEWS wins", () => {
    expect(newsPath({ MARCHYO_NEWS: import.meta.path })).toBe(import.meta.path);
  });
});

describe("--notify", () => {
  test("a fresh install records hash and baseline and stays silent", async () => {
    const f = fixture();
    const r = await whatsNew(f, ["--notify"]);
    expect(r.code).toBe(0);
    expect(f.fake.calls()).toEqual([]);
    expect(readFileSync(join(f.state, "seen-news"), "utf8").trim()).toBe(sha(NEWS_V1));
    expect(readFileSync(join(f.state, "seen-news.txt"), "utf8")).toBe(NEWS_V1);
  });

  test("an unchanged NEWS does nothing", async () => {
    const f = fixture();
    seed(f, NEWS_V1);
    const r = await whatsNew(f, ["--notify"]);
    expect(r.code).toBe(0);
    expect(f.fake.calls()).toEqual([]);
  });

  test("a changed NEWS sends one notification and records the hash only", async () => {
    const f = fixture(NEWS_V2);
    seed(f, NEWS_V1);
    const r = await whatsNew(f, ["--notify"]);
    expect(r.code).toBe(0);
    const calls = f.fake.calls();
    expect(calls).toHaveLength(1);
    const call = calls[0]!;
    expect(call.slice(0, 3)).toEqual(["--user", "--", "call"]);
    expect(call.slice(8, 14)).toEqual([
      "marchyo-action", "0", "", "Marchyo was updated", "1 new entry", "0",
    ]);
    const hint = (key: string): string => call[call.indexOf(key) + 2]!;
    const actions = JSON.parse(hint("marchyo-actions")) as { label: string; argv: string[] }[];
    expect(actions).toEqual([
      { label: "What's new", argv: ["marchyo", "shell", "open", "whatsnew"] },
    ]);
    expect(JSON.parse(hint("marchyo-exec-argv"))).toEqual(["marchyo", "shell", "open", "whatsnew"]);
    expect(hint("marchyo-token")).toMatch(/^[0-9a-f]{64}$/);
    expect(readFileSync(join(f.state, "seen-news"), "utf8").trim()).toBe(sha(NEWS_V2));
    expect(readFileSync(join(f.state, "seen-news.txt"), "utf8")).toBe(NEWS_V1);
    const again = await whatsNew(f, ["--notify"]);
    expect(again.code).toBe(0);
    expect(f.fake.calls()).toHaveLength(1);
  });

  test("a failing bus is logged, exits 0 and keeps the hash for a retry", async () => {
    const f = fixture(NEWS_V2);
    seed(f, NEWS_V1);
    writeFileSync(join(f.fake.dir, "bin", "busctl"), "#!/bin/sh\n[ \"$2\" = status ] && exit 0\nexit 1\n", {
      mode: 0o755,
    });
    const r = await whatsNew(f, ["--notify"]);
    expect(r.code).toBe(0);
    expect(r.stderr).toContain("could not send the notification");
    expect(readFileSync(join(f.state, "seen-news"), "utf8").trim()).toBe(sha(NEWS_V1));
  });

  test("it waits for the notification service and gives up quietly", async () => {
    const f = fixture(NEWS_V2);
    seed(f, NEWS_V1);
    const sleeps: number[] = [];
    let polls = 0;
    const deps: WhatsNewDeps = {
      env: { ...process.env, ...f.fake.env },
      newsPath: () => f.news,
      notify: { ...defaultNotifyDeps(), env: f.fake.env },
      wait: {
        timeoutMs: 3000,
        intervalMs: 1000,
        check: async () => ++polls > 100,
        sleep: async (ms) => void sleeps.push(ms),
      },
      summary: async () => [],
    };
    const rt: Runtime = {
      format: "text", noColor: true, forceColor: false, plain: true,
      noAnimation: true, noInput: true, quiet: true, verbose: 0,
    };
    const written: string[] = [];
    const stderr = spyOn(process.stderr, "write").mockImplementation((c) => {
      written.push(String(c));
      return true;
    });
    try {
      expect(await runWhatsNew(rt, { notify: true }, deps)).toBe(0);
      expect(await runWhatsNew(rt, { notify: true }, { ...deps, newsPath: () => null })).toBe(0);
    } finally {
      stderr.mockRestore();
    }
    expect(written.join("")).toContain("no notification service appeared within 3 s");
    expect(written.join("")).toContain("no NEWS file found");
    expect(sleeps).toEqual([1000, 1000, 1000]);
    expect(f.fake.calls()).toEqual([]);
    expect(existsSync(join(f.state, "seen-news"))).toBe(true);
    expect(readFileSync(join(f.state, "seen-news"), "utf8").trim()).toBe(sha(NEWS_V1));
  });
});

describe("--json and --mark-seen", () => {
  test("json shape for a changed NEWS", async () => {
    const f = fixture(NEWS_V2);
    seed(f, NEWS_V1);
    const r = await whatsNew(f, ["--json"]);
    expect(r.code).toBe(0);
    const out = JSON.parse(r.stdout) as Record<string, unknown>;
    expect(Object.keys(out).sort()).toEqual(["changed", "entries", "hash", "summary"]);
    expect(out.changed).toBe(true);
    expect(out.hash).toBe(sha(NEWS_V2));
    expect(out.entries).toEqual(["Brand new feature."]);
    expect(Array.isArray(out.summary)).toBe(true);
    expect((out.summary as unknown[]).every((l) => typeof l === "string")).toBe(true);
    expect((out.summary as string[]).length).toBeLessThanOrEqual(40);
  });

  test("unchanged NEWS is not changed", async () => {
    const f = fixture();
    seed(f, NEWS_V1);
    const out = JSON.parse((await whatsNew(f, ["--json"])).stdout) as { changed: boolean; entries: string[] };
    expect(out.changed).toBe(false);
    expect(out.entries).toEqual([]);
  });

  test("a hash change without new entries still counts as changed", async () => {
    const f = fixture(NEWS_V1);
    seed(f, NEWS_V1);
    writeFileSync(join(f.state, "seen-news"), "stale\n");
    const out = JSON.parse((await whatsNew(f, ["--json"])).stdout) as { changed: boolean };
    expect(out.changed).toBe(true);
  });

  test("plain output lists the entries", async () => {
    const f = fixture(NEWS_V2);
    seed(f, NEWS_V1);
    const r = await whatsNew(f);
    expect(r.stdout).toBe("- Brand new feature.\n");
  });

  test("--mark-seen records hash and baseline", async () => {
    const f = fixture(NEWS_V2);
    seed(f, NEWS_V1);
    const r = await whatsNew(f, ["--mark-seen"]);
    expect(r.code).toBe(0);
    expect(r.stdout).toBe("");
    expect(readFileSync(join(f.state, "seen-news"), "utf8").trim()).toBe(sha(NEWS_V2));
    expect(readFileSync(join(f.state, "seen-news.txt"), "utf8")).toBe(NEWS_V2);
    const after = JSON.parse((await whatsNew(f, ["--json"])).stdout) as { changed: boolean };
    expect(after.changed).toBe(false);
  });
});

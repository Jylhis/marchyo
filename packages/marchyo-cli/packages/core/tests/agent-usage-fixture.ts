import { chmodSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { UsageDeps } from "../src/agent-usage.ts";

// A throwaway HOME signed in to Claude Code, Codex and Copilot with fake
// secrets, a fake `codex app-server` on PATH, and a recording fetch.

export const CLAUDE_SECRET = "sk-ant-oat01-FAKE-CLAUDE-SECRET-0123456789";
export const GH_SECRET = "gho_FAKE-GITHUB-SECRET-0123456789";
export const CODEX_SECRET = "eyFAKE-CODEX-SECRET-0123456789";
export const SECRETS = [CLAUDE_SECRET, GH_SECRET, CODEX_SECRET];

export const FIXTURES = join(import.meta.dir, "fixtures", "agent-usage");
export const fixture = (name: string): string => readFileSync(join(FIXTURES, name), "utf8");

export interface Recorded {
  url: string;
  init: RequestInit;
}

export interface FakeHome {
  home: string;
  deps: UsageDeps;
  requests: Recorded[];
  clock: { now: number };
  respond: (url: URL) => Response | Promise<Response>;
  notices: string[];
}

function fakeCodex(bin: string): void {
  const reply = JSON.parse(fixture("codex-rate-limits.json"));
  const script = `#!${process.execPath}
const reply = ${JSON.stringify(reply)};
const out = (o) => process.stdout.write(JSON.stringify(o) + "\\n");
let buf = "";
for await (const chunk of Bun.stdin.stream()) {
  buf += new TextDecoder().decode(chunk);
  let i;
  while ((i = buf.indexOf("\\n")) >= 0) {
    const msg = JSON.parse(buf.slice(0, i));
    buf = buf.slice(i + 1);
    if (msg.id === 1) out({ id: 1, result: { userAgent: "codex-fake" } });
    if (msg.method === "account/rateLimits/read") {
      out({ method: "account/updated", params: {} });
      out({ ...reply, id: msg.id });
    }
  }
}
`;
  writeFileSync(join(bin, "codex"), script);
  chmodSync(join(bin, "codex"), 0o755);
}

export function fakeHome(now = Date.parse("2026-11-05T12:00:00Z")): FakeHome {
  const home = mkdtempSync(join(tmpdir(), "marchyo-agent-usage-"));
  const bin = join(home, "bin");
  mkdirSync(join(home, ".claude", "projects", "p"), { recursive: true });
  mkdirSync(join(home, ".codex"), { recursive: true });
  mkdirSync(join(home, ".copilot"), { recursive: true });
  mkdirSync(bin);
  writeFileSync(
    join(home, ".claude", ".credentials.json"),
    JSON.stringify({ claudeAiOauth: { accessToken: CLAUDE_SECRET, expiresAt: now + 3_600_000 } }),
  );
  writeFileSync(join(home, ".codex", "auth.json"), JSON.stringify({ tokens: { access_token: CODEX_SECRET } }));
  fakeCodex(bin);
  const requests: Recorded[] = [];
  const clock = { now };
  const fh: FakeHome = {
    home,
    requests,
    clock,
    notices: [],
    respond: (url) =>
      new Response(url.hostname === "api.anthropic.com" ? fixture("claude-oauth-usage.json") : fixture("copilot-user.json")),
    deps: undefined as unknown as UsageDeps,
  };
  fh.deps = {
    env: {
      PATH: bin,
      GH_TOKEN: GH_SECRET,
      XDG_STATE_HOME: join(home, "state"),
      XDG_DATA_HOME: join(home, "data"),
    },
    home,
    now: () => clock.now,
    fetch: async (url, init) => {
      requests.push({ url: url.toString(), init });
      return fh.respond(url);
    },
    ghToken: async () => "",
    notify: (title, body) => void fh.notices.push(`${title}\n${body}`),
  };
  return fh;
}

// Collect everything written to stdout/stderr/console while `fn` runs.
export async function captureOutput<T>(fn: () => Promise<T>): Promise<{ value: T; text: string }> {
  const chunks: string[] = [];
  const out = process.stdout.write.bind(process.stdout);
  const err = process.stderr.write.bind(process.stderr);
  const methods = ["log", "info", "warn", "error", "debug"] as const;
  const saved = methods.map((m) => console[m]);
  const sink = (chunk: unknown) => {
    chunks.push(String(chunk));
    return true;
  };
  process.stdout.write = sink as typeof process.stdout.write;
  process.stderr.write = sink as typeof process.stderr.write;
  for (const m of methods) console[m] = (...args: unknown[]) => void chunks.push(args.map(String).join(" "));
  try {
    const value = await fn();
    return { value, text: chunks.join("") };
  } finally {
    process.stdout.write = out;
    process.stderr.write = err;
    methods.forEach((m, i) => (console[m] = saved[i]!));
  }
}

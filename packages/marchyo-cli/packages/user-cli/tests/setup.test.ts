import { describe, expect, spyOn, test } from "bun:test";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { type Runtime, captureArgv } from "@marchyo/core";
import {
  type FixDeps,
  type SetupDeps,
  type SetupItem,
  type SetupProbe,
  collectSetupItems,
  fixArgv,
  runSetup,
  runSetupFix,
} from "../src/commands/setup.ts";
import { fakeBusctl, useSourceCatalog } from "./fake-busctl.ts";

useSourceCatalog();

const RT: Runtime = {
  format: "text", noColor: true, forceColor: false, plain: true,
  noAnimation: true, noInput: true, quiet: true, verbose: 0,
};

// Everything configured and present; each test breaks what it examines.
function probe(over: Partial<SetupProbe> = {}): SetupProbe {
  return {
    env: { AI_AGENT: "claude" },
    available: () => true,
    gitConfig: async (k) => (k === "user.name" ? "Ada" : "ada@example.com"),
    sshPublicKeys: () => ["id_ed25519.pub"],
    sshAgentHasKeys: async () => false,
    sshConfigNamesAgent: () => false,
    fidoEnrolled: () => true,
    fingerprint: async () => "enrolled",
    language: async () => ({ override: "de", baked: "en" }),
    themeOverride: async () => "nord",
    agentSignedIn: () => true,
    dictationBackend: () => "voxtype",
    dictationState: async () => "idle",
    ...over,
  };
}

async function item(over: Partial<SetupProbe>, id: string): Promise<SetupItem> {
  const found = (await collectSetupItems(probe(over))).find((i) => i.id === id);
  if (found === undefined) throw new Error(`no item ${id}`);
  return found;
}

describe("items", () => {
  test("everything configured: no todo, no fix", async () => {
    const items = await collectSetupItems(probe());
    expect(items.map((i) => i.id)).toEqual([
      "git", "ssh", "fido2", "fingerprint", "language", "keyboard", "theme", "agent", "dictation",
    ]);
    expect(items.filter((i) => i.status === "todo")).toEqual([]);
    expect(items.every((i) => i.fix === null)).toBe(true);
    expect(items.find((i) => i.id === "keyboard")!.status).toBe("skip");
  });

  test("a todo carries the fix command", async () => {
    const git = await item({ gitConfig: async () => "" }, "git");
    expect(git.status).toBe("todo");
    expect(git.detail).toBe("Not set: user.name, user.email");
    expect(git.fix).toEqual({
      label: "Set name and email",
      argv: ["marchyo", "setup", "fix", "git"],
    });
    expect(git.fix!.argv).toEqual(fixArgv("git"));
  });

  test("git needs both name and email", async () => {
    const half = await item({ gitConfig: async (k) => (k === "user.name" ? "Ada" : "") }, "git");
    expect(half.status).toBe("todo");
    expect(half.detail).toBe("Not set: user.email");
  });

  test("ssh: a public key, an agent config or agent keys count", async () => {
    const none = { sshPublicKeys: () => [] };
    expect((await item(none, "ssh")).status).toBe("todo");
    expect((await item({ ...none, sshConfigNamesAgent: () => true }, "ssh")).status).toBe("done");
    expect((await item({ ...none, sshAgentHasKeys: async () => true }, "ssh")).status).toBe("done");
  });

  test("fido2: skipped without the tool, todo until enrolled", async () => {
    expect((await item({ available: (c) => c !== "pamu2fcfg" }, "fido2")).status).toBe("skip");
    const todo = await item({ fidoEnrolled: () => false }, "fido2");
    expect(todo.status).toBe("todo");
    expect(todo.fix!.argv.slice(-3)).toEqual(["setup", "fix", "fido2"]);
  });

  test("fingerprint: skipped without the tool or a reader", async () => {
    expect((await item({ available: (c) => c !== "fprintd-enroll" }, "fingerprint")).status).toBe("skip");
    expect((await item({ fingerprint: async () => "no-device" }, "fingerprint")).status).toBe("skip");
    expect((await item({ fingerprint: async () => "none" }, "fingerprint")).status).toBe("todo");
  });

  test("language: an override or a non-default language is done", async () => {
    expect((await item({ language: async () => ({ override: null, baked: "fi" }) }, "language")).status).toBe("done");
    expect((await item({ language: async () => ({ override: null, baked: "en" }) }, "language")).status).toBe("todo");
    expect((await item({ language: async () => ({ override: null, baked: null }) }, "language")).status).toBe("skip");
  });

  test("theme: done once chosen at run time", async () => {
    expect((await item({ themeOverride: async () => null }, "theme")).status).toBe("todo");
    expect((await item({}, "theme")).detail).toBe("nord");
  });

  test("agent: skip without AI_AGENT or a managed provider, todo when signed out", async () => {
    expect((await item({ env: {} }, "agent")).status).toBe("skip");
    expect((await item({ env: { AI_AGENT: "aider" } }, "agent")).status).toBe("skip");
    const out = await item({ env: { AI_AGENT: "/bin/codex --yolo" }, agentSignedIn: () => false }, "agent");
    expect(out.status).toBe("todo");
    expect(out.detail).toBe("Not signed in to codex");
  });

  test("dictation: skip when off or missing, todo when stopped", async () => {
    expect((await item({ dictationBackend: () => null }, "dictation")).status).toBe("skip");
    expect((await item({ available: (c) => c !== "voxtype" }, "dictation")).status).toBe("skip");
    expect((await item({ dictationState: async () => "stopped" }, "dictation")).status).toBe("todo");
    expect((await item({ dictationState: async () => "recording" }, "dictation")).status).toBe("done");
  });
});

function setupFixture(over: Partial<SetupProbe> = {}) {
  const fake = fakeBusctl();
  const deps: SetupDeps = {
    env: { XDG_STATE_HOME: join(fake.dir, "state"), XDG_RUNTIME_DIR: join(fake.dir, "runtime") },
    probe: () => probe(over),
    notify: {
      env: { XDG_RUNTIME_DIR: join(fake.dir, "runtime") },
      run: (argv) => captureArgv([join(fake.dir, "bin", "busctl"), ...argv.slice(1)]),
    },
    wait: { timeoutMs: 0, intervalMs: 1, check: async () => true, sleep: async () => {} },
  };
  return { fake, deps, flag: (n: string) => join(fake.dir, "state", "marchyo", n) };
}

describe("welcome", () => {
  test("one notification when something is todo, then never again", async () => {
    const f = setupFixture({ gitConfig: async () => "", sshPublicKeys: () => [] });
    expect(await runSetup(RT, { welcome: true }, f.deps)).toBe(0);
    const calls = f.fake.calls();
    expect(calls).toHaveLength(1);
    const call = calls[0]!;
    expect(call.slice(8, 14)).toEqual([
      "marchyo-action", "0", "", "Welcome to Marchyo", "2 things to set up", "0",
    ]);
    const actions = JSON.parse(call[call.indexOf("marchyo-actions") + 2]!) as unknown;
    expect(actions).toEqual([{ label: "Set up", argv: ["marchyo", "shell", "open", "setup"] }]);
    expect(call).toContain("marchyo-token");
    expect(existsSync(f.flag("setup-welcomed"))).toBe(true);
    await runSetup(RT, { welcome: true }, f.deps);
    expect(f.fake.calls()).toHaveLength(1);
  });

  test("the singular reads naturally", async () => {
    const f = setupFixture({ gitConfig: async () => "" });
    await runSetup(RT, { welcome: true }, f.deps);
    expect(f.fake.calls()[0]).toContain("1 thing to set up");
  });

  test("nothing todo: silent and no flag", async () => {
    const f = setupFixture();
    expect(await runSetup(RT, { welcome: true }, f.deps)).toBe(0);
    expect(f.fake.calls()).toEqual([]);
    expect(existsSync(f.flag("setup-welcomed"))).toBe(false);
  });

  test("setup-done silences it", async () => {
    const f = setupFixture({ gitConfig: async () => "" });
    await runSetup(RT, { done: true }, f.deps);
    expect(existsSync(f.flag("setup-done"))).toBe(true);
    await runSetup(RT, { welcome: true }, f.deps);
    expect(f.fake.calls()).toEqual([]);
  });

  test("no notification service: exit 0, no flag", async () => {
    const f = setupFixture({ gitConfig: async () => "" });
    f.deps.wait = { timeoutMs: 2, intervalMs: 1, check: async () => false, sleep: async () => {} };
    const stderr = spyOn(process.stderr, "write").mockImplementation(() => true);
    try {
      expect(await runSetup(RT, { welcome: true }, f.deps)).toBe(0);
    } finally {
      stderr.mockRestore();
    }
    expect(f.fake.calls()).toEqual([]);
    expect(existsSync(f.flag("setup-welcomed"))).toBe(false);
  });
});

describe("output", () => {
  test("--json shape and doneFlag", async () => {
    const f = setupFixture({ gitConfig: async () => "" });
    const lines: string[] = [];
    const out = spyOn(process.stdout, "write").mockImplementation((c) => {
      lines.push(String(c));
      return true;
    });
    try {
      await runSetup({ ...RT, format: "json" }, {}, f.deps);
      await runSetup(RT, { done: true }, f.deps);
      await runSetup({ ...RT, format: "json" }, {}, f.deps);
    } finally {
      out.mockRestore();
    }
    const [before, after] = lines.map((l) => JSON.parse(l) as { items: SetupItem[]; doneFlag: boolean });
    expect(Object.keys(before!).sort()).toEqual(["doneFlag", "items"]);
    expect(before!.doneFlag).toBe(false);
    expect(after!.doneFlag).toBe(true);
    expect(Object.keys(before!.items[0]!).sort()).toEqual(["detail", "fix", "id", "status", "title"]);
    expect(before!.items.find((i) => i.id === "git")!.fix).not.toBeNull();
  });

  test("the text checklist marks each state", async () => {
    const f = setupFixture({ gitConfig: async () => "" });
    const lines: string[] = [];
    const out = spyOn(process.stdout, "write").mockImplementation((c) => {
      lines.push(String(c));
      return true;
    });
    try {
      await runSetup(RT, {}, f.deps);
    } finally {
      out.mockRestore();
    }
    const text = lines.join("");
    expect(text).toContain("[ ] Git identity: Not set: user.name, user.email");
    expect(text).toMatch(/\[x\] SSH key: id_ed25519\.pub/);
    expect(text).toContain("[-] Keyboard layout: Set in marchyo.keyboard");
  });

  test("--done writes the flag", async () => {
    const f = setupFixture();
    expect(await runSetup(RT, { done: true }, f.deps)).toBe(0);
    expect(readFileSync(f.flag("setup-done"), "utf8")).toBe("");
  });
});

function fixDeps(answers: string[] = [], config: Record<string, string> = {}) {
  const ran: string[][] = [];
  const asked: string[] = [];
  const deps: FixDeps = {
    env: { AI_AGENT: "claude" },
    run: async (argv) => {
      ran.push(argv);
      return 0;
    },
    ask: async (q) => {
      asked.push(q);
      return answers.shift() ?? "";
    },
    gitConfig: async (k) => config[k] ?? "",
  };
  return { deps, ran, asked };
}

describe("fix", () => {
  test("an unknown id is a usage error", async () => {
    const stderr = spyOn(process.stderr, "write").mockImplementation(() => true);
    try {
      expect(await runSetupFix(RT, "bogus", fixDeps().deps)).toBe(2);
    } finally {
      stderr.mockRestore();
    }
  });

  test("git prompts for what is missing and runs git config", async () => {
    const f = fixDeps(["Ada", "ada@example.com", ""]);
    expect(await runSetupFix(RT, "git", f.deps)).toBe(0);
    expect(f.ran).toEqual([
      ["git", "config", "--global", "user.name", "Ada"],
      ["git", "config", "--global", "user.email", "ada@example.com"],
    ]);
    const half = fixDeps(["new@example.com", ""], { "user.name": "Ada" });
    await runSetupFix(RT, "git", half.deps);
    expect(half.ran).toEqual([["git", "config", "--global", "user.email", "new@example.com"]]);
  });

  test("ssh and the hand-overs", async () => {
    const cases: [string, string[]][] = [
      ["ssh", ["ssh-keygen", "-t", "ed25519"]],
      ["fido2", ["marchyo", "security", "enroll", "fido2"]],
      ["fingerprint", ["marchyo", "security", "enroll", "fingerprint"]],
      ["agent", ["marchyo", "agent", "account", "add", "claude"]],
      ["dictation", ["marchyo", "dictation", "start"]],
    ];
    for (const [id, argv] of cases) {
      const f = fixDeps();
      expect(await runSetupFix(RT, id, f.deps)).toBe(0);
      expect(f.ran).toEqual([argv]);
    }
  });

  test("language and theme list the choices, ask, then apply", async () => {
    const lang = fixDeps(["de", ""]);
    await runSetupFix(RT, "language", lang.deps);
    expect(lang.ran).toEqual([["marchyo", "language", "list"], ["marchyo", "language", "de"]]);
    const theme = fixDeps(["nord", ""]);
    await runSetupFix(RT, "theme", theme.deps);
    expect(theme.ran).toEqual([["marchyo", "theme", "list"], ["marchyo", "theme", "set", "nord"]]);
    const none = fixDeps(["", ""]);
    expect(await runSetupFix(RT, "theme", none.deps)).toBe(1);
  });

  test("a failing or throwing step is reported, never thrown", async () => {
    const f = fixDeps();
    f.deps.run = async () => {
      throw new Error("spawn failed");
    };
    const stderr = spyOn(process.stderr, "write").mockImplementation(() => true);
    try {
      expect(await runSetupFix(RT, "ssh", f.deps)).toBe(1);
    } finally {
      stderr.mockRestore();
    }
  });

  test("keyboard has nothing to fix", async () => {
    const f = fixDeps();
    expect(await runSetupFix(RT, "keyboard", f.deps)).toBe(0);
    expect(f.ran).toEqual([]);
  });
});

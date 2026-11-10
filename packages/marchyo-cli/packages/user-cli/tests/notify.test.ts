import { describe, expect, test } from "bun:test";
import {
  chmodSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  statSync,
  symlinkSync,
  utimesSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";
import {
  NotifyUsageError,
  busctlNotifyArgv,
  issueNonce,
  notifyHints,
  parseNotifyArgs,
} from "@marchyo/core";
import { checkNotifyNonceDir } from "../src/commands/doctor.ts";
import { splitNotifyArgv } from "../src/notify-argv.ts";
import { fakeBusctl, useSourceCatalog } from "./fake-busctl.ts";

useSourceCatalog();

const CLI = join(import.meta.dir, "..", "src", "cli.tsx");
const TOKEN = "a".repeat(64);

function failure(args: string[]): NotifyUsageError {
  try {
    parseNotifyArgs(args);
  } catch (e) {
    if (e instanceof NotifyUsageError) return e;
    throw e;
  }
  throw new Error("expected a usage error");
}

describe("parse", () => {
  test("defaults", () => {
    const r = parseNotifyArgs(["Hello"]);
    expect(r).toMatchObject({
      appName: "marchyo-action",
      urgency: "low",
      expire: -1,
      replaceId: 0,
      headline: "Hello",
      description: "",
      exec: null,
      actions: [],
      printId: false,
      transient: false,
    });
  });

  test("every value flag in both forms, before the headline", () => {
    const pairs: [string[], string[]][] = [
      [["--app-name", "x"], ["--app-name=x"]],
      [["-g", "G"], ["--glyph", "G"]],
      [["-u", "critical"], ["--urgency=critical"]],
      [["-i", "ico"], ["--icon=ico"]],
      [["--image", "/a.png"], ["--image=/a.png"]],
      [["-t", "500"], ["--expire-time=500"]],
      [["-r", "7"], ["--replace-id=7"]],
    ];
    for (const [a, b] of pairs) {
      expect(parseNotifyArgs([...a, "H"])).toEqual(parseNotifyArgs([...b, "H"]));
    }
    const all = parseNotifyArgs([
      "--app-name=app", "-g", "G", "-u", "normal", "-i", "ico", "--image=/a.png",
      "-t", "-1", "-r", "7", "-p", "--transient", "H", "D",
    ]);
    expect(all).toMatchObject({
      appName: "app", glyph: "G", urgency: "normal", icon: "ico", image: "/a.png",
      expire: -1, replaceId: 7, printId: true, transient: true, headline: "H", description: "D",
    });
  });

  test("flags after the description", () => {
    const r = parseNotifyArgs(["H", "D", "-u", "critical", "--glyph=G", "-p", "--transient"]);
    expect(r).toMatchObject({ urgency: "critical", glyph: "G", printId: true, transient: true });
  });

  test("a description that starts with a dash is text", () => {
    expect(parseNotifyArgs(["H", "-50% off"]).description).toBe("-50% off");
    expect(parseNotifyArgs(["H", "--hint=x"]).description).toBe("--hint=x");
    expect(parseNotifyArgs(["H", "--with"]).description).toBe("--with");
  });

  test("a known flag in the description slot is not the description", () => {
    const r = parseNotifyArgs(["H", "-u", "critical"]);
    expect(r.description).toBe("");
    expect(r.urgency).toBe("critical");
    expect(parseNotifyArgs(["H", "--transient"]).transient).toBe(true);
  });

  test("--exec as the headline is text", () => {
    const r = parseNotifyArgs(["--exec", "body"]);
    expect(r.headline).toBe("--exec");
    expect(r.description).toBe("body");
    expect(r.exec).toBeNull();
  });

  test("a headline that looks like a hint stays an argument", () => {
    const r = parseNotifyArgs(["--hint=x", "-rf"]);
    expect(r.headline).toBe("--hint=x");
    expect(r.description).toBe("-rf");
    const argv = busctlNotifyArgv(r, null);
    expect(argv.indexOf("--")).toBe(2);
    expect(argv).toContain("--hint=x");
  });

  test("--transient=false is not the bare flag", () => {
    expect(parseNotifyArgs(["--transient=false", "x"]).headline).toBe("--transient=false");
    expect(failure(["H", "D", "--transient=false"]).lines).toEqual([
      "Unknown option: --transient=false",
    ]);
  });

  test("--exec takes the rest of the line", () => {
    const r = parseNotifyArgs(["H", "D", "--exec", "marchyo", "shell", "open", "-p", "--exec"]);
    expect(r.exec).toEqual(["marchyo", "shell", "open", "-p", "--exec"]);
    expect(r.printId).toBe(false);
  });

  test("--action words end at the next --action, --with or --exec", () => {
    const r = parseNotifyArgs([
      "H", "D",
      "--action", "One", "prog", "a", "b",
      "--action", "Two", "other",
      "--with", "x", "--action", "y",
    ]);
    expect(r.actions).toEqual([
      { label: "One", argv: ["prog", "a", "b", "x", "--action", "y"] },
      { label: "Two", argv: ["other", "x", "--action", "y"] },
    ]);
  });

  test("flags may follow an action", () => {
    const r = parseNotifyArgs(["H", "--action", "Go", "p", "--with", "arg"]);
    expect(r.actions).toEqual([{ label: "Go", argv: ["p", "arg"] }]);
  });
});

describe("errors", () => {
  test("no headline prints the usage", () => {
    const e = failure([]);
    expect(e.showUsage).toBe(true);
    expect(failure(["-p"]).showUsage).toBe(true);
  });

  test("missing values", () => {
    expect(failure(["-u"]).lines).toEqual(["Missing value for -u"]);
    expect(failure(["H", "D", "--image"]).lines).toEqual(["Missing value for --image"]);
    expect(failure(["--glyph"]).lines).toEqual(["Missing value for --glyph"]);
  });

  test("an empty --flag=value is a value", () => {
    expect(parseNotifyArgs(["--glyph=", "H"]).glyph).toBe("");
  });

  test("bad urgency", () => {
    expect(failure(["-u", "loud", "H"]).lines).toEqual([
      "Unknown urgency: loud (use low, normal, or critical)",
    ]);
  });

  test("bad numbers", () => {
    expect(failure(["-r", "x", "H"]).lines).toEqual(["Invalid -r value (numeric id expected): x"]);
    expect(failure(["--replace-id=-1", "H"]).lines[0]).toContain("numeric id expected");
    expect(failure(["-t", "1.5", "H"]).lines).toEqual([
      "Invalid -t value (milliseconds expected): 1.5",
    ]);
    expect(parseNotifyArgs(["-t", "-1", "H"]).expire).toBe(-1);
  });

  test("unknown option", () => {
    const e = failure(["H", "D", "--bogus"]);
    expect(e.lines).toEqual(["Unknown option: --bogus"]);
    expect(e.showUsage).toBe(true);
  });

  test("--exec problems", () => {
    expect(failure(["H", "D", "--exec"]).lines).toEqual([
      "--exec needs a command: --exec <program> [args...]",
    ]);
    expect(failure(["H", "D", "--exec", ""]).lines[0]).toContain("--exec needs a command");
    expect(failure(["H", "D", "--exec", "ls -l"]).lines).toEqual([
      "--exec takes the command as separate words, not one quoted string.",
      "Write:  --exec ls -l",
    ]);
    expect(parseNotifyArgs(["H", "D", "--exec", "ls -l", "x"]).exec).toEqual(["ls -l", "x"]);
  });

  test("--action problems", () => {
    const needs = "--action needs a label and a command: --action <label> <program> [words...]";
    expect(failure(["H", "--action"]).lines).toEqual([needs]);
    expect(failure(["H", "--action", "Label"]).lines).toEqual([needs]);
    expect(failure(["H", "--action", "", "p"]).lines).toEqual([needs]);
    expect(failure(["H", "--action", "L", ""]).lines).toEqual([needs]);
    expect(failure(["H", "--action", "L", "--with", "x"]).lines).toEqual([needs]);
    expect(failure(["H", "--action", "Open", "ls -l"]).lines).toEqual([
      "--action takes the command as separate words, not one quoted string.",
      'Write:  --action "Open" ls -l',
    ]);
  });

  test("--exec with --action, too many actions, stray --with", () => {
    expect(failure(["H", "--action", "A", "p", "--exec", "q"]).lines).toEqual([
      "--exec and --action cannot be combined: the card click runs the first action.",
    ]);
    const four = ["H"];
    for (const n of "ABCD") four.push("--action", n, "p");
    expect(failure(four).lines).toEqual(["A notification takes at most 3 actions."]);
    expect(failure(["H", "D", "--with", "x"]).lines).toEqual([
      "--with gives arguments to --action; it needs at least one --action before it.",
    ]);
  });
});

describe("hints and busctl argv", () => {
  test("a plain card has only urgency and no token", () => {
    const r = parseNotifyArgs(["Hi", "There"]);
    expect(busctlNotifyArgv(r, null)).toEqual([
      "busctl", "--user", "--", "call",
      "org.freedesktop.Notifications", "/org/freedesktop/Notifications",
      "org.freedesktop.Notifications", "Notify", "susssasa{sv}i",
      "marchyo-action", "0", "", "Hi", "There", "0",
      "1", "urgency", "y", "0",
      "-1",
    ]);
  });

  test("every hint, in order", () => {
    const r = parseNotifyArgs([
      "--app-name=app", "-g", "G", "-u", "critical", "-i", "ico", "--image=/p.png",
      "-t", "3000", "-r", "9", "--transient", "H", "D",
      "--exec", "marchyo", "shell", "open", "x y",
    ]);
    expect(busctlNotifyArgv(r, TOKEN)).toEqual([
      "busctl", "--user", "--", "call",
      "org.freedesktop.Notifications", "/org/freedesktop/Notifications",
      "org.freedesktop.Notifications", "Notify", "susssasa{sv}i",
      "app", "9", "ico", "H", "D", "0",
      "6",
      "urgency", "y", "2",
      "marchyo-glyph", "s", "G",
      "image-path", "s", "/p.png",
      "transient", "b", "true",
      "marchyo-exec-argv", "s", '["marchyo","shell","open","x y"]',
      "marchyo-token", "s", TOKEN,
      "3000",
    ]);
  });

  test("actions set marchyo-actions and the first action's argv", () => {
    const r = parseNotifyArgs([
      "H", "--action", "A", "p", "1", "--action", "B", "q", "--with", "z",
    ]);
    expect(notifyHints(r, TOKEN)).toEqual([
      "urgency", "y", "0",
      "marchyo-actions", "s", '[{"label":"A","argv":["p","1","z"]},{"label":"B","argv":["q","z"]}]',
      "marchyo-exec-argv", "s", '["p","1","z"]',
      "marchyo-token", "s", TOKEN,
    ]);
  });

  test("the token is demanded for click commands and glyphs only", () => {
    expect(() => notifyHints(parseNotifyArgs(["H", "--exec", "p"]), null)).toThrow();
    expect(() => notifyHints(parseNotifyArgs(["-g", "G", "H"]), null)).toThrow();
    expect(notifyHints(parseNotifyArgs(["-g", "G", "H"]), TOKEN)).toContain("marchyo-token");
    expect(notifyHints(parseNotifyArgs(["H"]), null)).not.toContain("marchyo-token");
    expect(notifyHints(parseNotifyArgs(["H", "-u", "critical", "--transient"]), null)).not.toContain(
      "marchyo-token",
    );
  });
});

describe("one-time token files", () => {
  const nonceDir = (dir: string) => join(dir, "rt", "marchyo", "notify-nonce");

  test("each call makes a fresh private file named by its own content", () => {
    const { dir } = fakeBusctl();
    const env = { XDG_RUNTIME_DIR: join(dir, "rt") };
    const first = issueNonce(env);
    const second = issueNonce(env);
    expect(first).toMatch(/^[0-9a-f]{64}$/);
    expect(second).not.toBe(first);
    expect(statSync(nonceDir(dir)).mode & 0o777).toBe(0o700);
    for (const n of [first, second]) {
      expect(statSync(join(nonceDir(dir), n)).mode & 0o777).toBe(0o600);
      expect(readFileSync(join(nonceDir(dir), n), "utf8")).toBe(n);
    }
  });

  test("files nobody spent are dropped after two minutes", () => {
    const { dir } = fakeBusctl();
    const env = { XDG_RUNTIME_DIR: join(dir, "rt") };
    const old = issueNonce(env);
    const recent = issueNonce(env);
    const past = new Date(Date.now() - 600_000);
    utimesSync(join(nonceDir(dir), old), past, past);
    writeFileSync(join(nonceDir(dir), "keep.txt"), "x");
    issueNonce(env);
    const names = readdirSync(nonceDir(dir));
    expect(names).not.toContain(old);
    expect(names).toContain(recent);
    expect(names).toContain("keep.txt");
  });

  test("refuses a directory that is open to others or is a link", () => {
    const loose = fakeBusctl();
    mkdirSync(nonceDir(loose.dir), { recursive: true, mode: 0o755 });
    expect(statSync(nonceDir(loose.dir)).mode & 0o077).not.toBe(0);
    expect(() => issueNonce({ XDG_RUNTIME_DIR: join(loose.dir, "rt") })).toThrow("unsafe");

    const linked = fakeBusctl();
    mkdirSync(join(linked.dir, "elsewhere"), { mode: 0o700 });
    mkdirSync(join(linked.dir, "rt", "marchyo"), { recursive: true, mode: 0o700 });
    symlinkSync(join(linked.dir, "elsewhere"), nonceDir(linked.dir));
    expect(() => issueNonce({ XDG_RUNTIME_DIR: join(linked.dir, "rt") })).toThrow("unsafe");
    expect(readdirSync(join(linked.dir, "elsewhere"))).toEqual([]);

    const open = fakeBusctl();
    mkdirSync(join(open.dir, "rt", "marchyo"), { recursive: true });
    chmodSync(join(open.dir, "rt", "marchyo"), 0o777);
    expect(() => issueNonce({ XDG_RUNTIME_DIR: join(open.dir, "rt") })).toThrow("unsafe");
  });

  test("a shared runtime directory that is merely world-readable is fine", () => {
    const { dir } = fakeBusctl();
    mkdirSync(join(dir, "rt", "marchyo"), { recursive: true, mode: 0o755 });
    expect(issueNonce({ XDG_RUNTIME_DIR: join(dir, "rt") })).toMatch(/^[0-9a-f]{64}$/);
  });

  test("refuses without XDG_RUNTIME_DIR", () => {
    expect(() => issueNonce({})).toThrow("XDG_RUNTIME_DIR");
  });
});

describe("doctor: notification tokens", () => {
  test("skips with nothing to look at, passes private, fails open", () => {
    expect(checkNotifyNonceDir(null).status).toBe("skip");
    const { dir } = fakeBusctl();
    expect(checkNotifyNonceDir(join(dir, "none")).status).toBe("skip");
    const env = { XDG_RUNTIME_DIR: join(dir, "rt") };
    issueNonce(env);
    const leaf = join(dir, "rt", "marchyo", "notify-nonce");
    expect(checkNotifyNonceDir(leaf).status).toBe("pass");
    chmodSync(leaf, 0o755);
    const open = checkNotifyNonceDir(leaf);
    expect(open.status).toBe("fail");
    expect(open.detail).toContain("755");
    chmodSync(leaf, 0o700);
    expect(checkNotifyNonceDir(leaf, (process.getuid?.() ?? 0) + 1).status).toBe("fail");
  });
});

describe("limits the shell enforces", () => {
  test("a program that starts with a dash", () => {
    expect(failure(["H", "--exec", "-rf", "x"]).lines).toEqual([
      "--exec needs a program, not an option: -rf",
    ]);
    expect(failure(["H", "--action", "Go", "--oops"]).lines).toEqual([
      "--action needs a program, not an option: --oops",
    ]);
    expect(parseNotifyArgs(["H", "--exec", "p", "-rf"]).exec).toEqual(["p", "-rf"]);
  });

  test("more than 32 words", () => {
    const words = Array.from({ length: 33 }, (_, i) => `w${i}`);
    expect(failure(["H", "--exec", ...words]).lines).toEqual(["--exec takes at most 32 words."]);
    expect(parseNotifyArgs(["H", "--exec", ...words.slice(0, 32)]).exec).toHaveLength(32);
    const withArgs = Array.from({ length: 32 }, (_, i) => `a${i}`);
    expect(failure(["H", "--action", "Go", "p", "--with", ...withArgs]).lines).toEqual([
      "--action takes at most 32 words.",
    ]);
  });

  test("a word over 4096 characters", () => {
    const long = "x".repeat(4097);
    expect(failure(["H", "--exec", "p", long]).lines).toEqual([
      "--exec words can have at most 4096 characters.",
    ]);
    expect(failure(["H", "--action", "Go", "p", long]).lines).toEqual([
      "--action words can have at most 4096 characters.",
    ]);
    expect(parseNotifyArgs(["H", "--exec", "p", "x".repeat(4096)]).exec).toHaveLength(2);
  });

  test("a blank action label", () => {
    expect(failure(["H", "--action", "  ", "p"]).lines).toEqual([
      "--action needs a label that is not blank.",
    ]);
  });

  test("a command whose JSON would not fit the hint", () => {
    const words = Array.from({ length: 12 }, () => "x".repeat(4000));
    expect(failure(["H", "--exec", "p", ...words.slice(0, 11)]).lines).toEqual([
      "--exec is too long.",
    ]);
  });
});

describe("argv before `notify`", () => {
  test("global options are split off, the rest stays untouched", () => {
    expect(splitNotifyArgv(["notify", "H", "--exec", "p"])).toEqual({
      globals: [],
      rest: ["H", "--exec", "p"],
    });
    expect(splitNotifyArgv(["--json", "-F", "json", "--color=never", "-qv", "notify", "-u", "x"])).toEqual({
      globals: ["--json", "-F", "json", "--color=never", "-qv"],
      rest: ["-u", "x"],
    });
    expect(splitNotifyArgv(["--plain", "notify"])).toEqual({ globals: ["--plain"], rest: [] });
  });

  test("anything else is left to commander", () => {
    expect(splitNotifyArgv(["status", "notify"])).toBeNull();
    expect(splitNotifyArgv(["--bogus", "notify"])).toBeNull();
    expect(splitNotifyArgv(["--format"])).toBeNull();
    expect(splitNotifyArgv(["--json"])).toBeNull();
    expect(splitNotifyArgv([])).toBeNull();
  });
});

async function notify(args: string[], env: Record<string, string>, globals: string[] = []) {
  const proc = Bun.spawn([process.execPath, CLI, ...globals, "notify", ...args], {
    stdout: "pipe",
    stderr: "pipe",
    env: { ...process.env, NO_COLOR: "1", ...env },
  });
  const code = await proc.exited;
  return {
    code,
    stdout: await new Response(proc.stdout).text(),
    stderr: await new Response(proc.stderr).text(),
  };
}

describe("marchyo notify", () => {
  test("sends over busctl, flags after the headline reach the parser", async () => {
    const fake = fakeBusctl();
    const r = await notify(["Title", "-50% off", "-u", "critical", "-p", "--glyph=G"], fake.env);
    expect(r.code).toBe(0);
    expect(r.stdout).toBe("42\n");
    const [call] = fake.calls();
    expect(call!.slice(0, 9)).toEqual([
      "--user", "--", "call",
      "org.freedesktop.Notifications", "/org/freedesktop/Notifications",
      "org.freedesktop.Notifications", "Notify", "susssasa{sv}i", "marchyo-action",
    ]);
    expect(call).toContain("-50% off");
    expect(call!.slice(-11, -3)).toEqual(["3", "urgency", "y", "2", "marchyo-glyph", "s", "G", "marchyo-token"]);
    expect(call!.at(-1)).toBe("-1");
  });

  test("a plain card writes no token file", async () => {
    const fake = fakeBusctl();
    const r = await notify(["Title", "-u", "critical"], fake.env);
    expect(r.code).toBe(0);
    expect(fake.calls()[0]).not.toContain("marchyo-token");
    expect(existsSync(join(fake.dir, "runtime", "marchyo", "notify-nonce"))).toBe(false);
  });

  test("--exec adds a one-time token and never prints it", async () => {
    const fake = fakeBusctl();
    const r = await notify(["Title", "Body", "--exec", "marchyo", "shell", "open", "audio"], fake.env);
    expect(r.code).toBe(0);
    const [call] = fake.calls();
    const token = call![call!.indexOf("marchyo-token") + 2]!;
    expect(token).toMatch(/^[0-9a-f]{64}$/);
    const file = join(fake.dir, "runtime", "marchyo", "notify-nonce", token);
    expect(readFileSync(file, "utf8")).toBe(token);
    expect(statSync(file).mode & 0o777).toBe(0o600);
    expect(r.stdout + r.stderr).not.toContain(token);
    const again = await notify(["Title", "Body", "--exec", "true"], fake.env);
    expect(again.code).toBe(0);
    const second = fake.calls()[1]!;
    expect(second[second.indexOf("marchyo-token") + 2]).not.toBe(token);
  });

  test("global options before notify do not eat the click command", async () => {
    const fake = fakeBusctl();
    const r = await notify(
      ["Title", "--exec", "marchyo", "--json", "-q", "--plain", "shell", "open", "x"],
      fake.env,
      ["--plain", "-F", "text"],
    );
    expect(r.code).toBe(0);
    const [call] = fake.calls();
    const hint = call![call!.indexOf("marchyo-exec-argv") + 2]!;
    expect(JSON.parse(hint)).toEqual(["marchyo", "--json", "-q", "--plain", "shell", "open", "x"]);
  });

  test("a leading-dash program exits 2 before anything is sent", async () => {
    const fake = fakeBusctl();
    const r = await notify(["Title", "--exec", "-rf", "/"], fake.env);
    expect(r.code).toBe(2);
    expect(r.stderr).toContain("needs a program, not an option");
    expect(fake.calls()).toEqual([]);
  });

  test("a click command without XDG_RUNTIME_DIR is refused", async () => {
    const fake = fakeBusctl();
    const env = { ...fake.env, XDG_RUNTIME_DIR: "" };
    const r = await notify(["Title", "--exec", "true"], env);
    expect(r.code).toBe(1);
    expect(r.stderr).toContain("XDG_RUNTIME_DIR");
    expect(fake.calls()).toEqual([]);
  });

  test("usage errors exit 2 and send nothing", async () => {
    const fake = fakeBusctl();
    for (const args of [[], ["H", "-u", "loud"], ["H", "--exec", "a b"], ["H", "--action", "A", "p", "--exec", "q"]]) {
      const r = await notify(args, fake.env);
      expect(r.code).toBe(2);
    }
    expect(fake.calls()).toEqual([]);
  });

  test("--help prints the help", async () => {
    const r = await notify(["--help"], {});
    expect(r.code).toBe(0);
    expect(r.stdout).toContain("--action <label>");
  });
});

import { test, expect } from "bun:test";
import {
  ok,
  err,
  warn,
  info,
  data,
  usageError,
} from "../src/output.ts";
import { buildRuntime } from "../src/runtime.ts";

type Capture = {
  stdout: string;
  stderr: string;
  restore: () => void;
};

function captureStdio(): Capture {
  let stdoutBuf = "";
  let stderrBuf = "";
  const origOut = process.stdout.write.bind(process.stdout);
  const origErr = process.stderr.write.bind(process.stderr);
  process.stdout.write = ((chunk: unknown) => {
    stdoutBuf += String(chunk);
    return true;
  }) as typeof process.stdout.write;
  process.stderr.write = ((chunk: unknown) => {
    stderrBuf += String(chunk);
    return true;
  }) as typeof process.stderr.write;
  return {
    get stdout() {
      return stdoutBuf;
    },
    get stderr() {
      return stderrBuf;
    },
    restore() {
      process.stdout.write = origOut;
      process.stderr.write = origErr;
    },
  };
}

test("ok/err/warn/info all write to stderr only", () => {
  const cap = captureStdio();
  try {
    const rt = buildRuntime({}, {}, true);
    ok(rt, "saved");
    err(rt, "boom");
    warn(rt, "iffy");
    info(rt, "fyi");
    expect(cap.stdout).toBe("");
    expect(cap.stderr).toContain("saved");
    expect(cap.stderr).toContain("boom");
    expect(cap.stderr).toContain("iffy");
    expect(cap.stderr).toContain("fyi");
  } finally {
    cap.restore();
  }
});

test("--quiet suppresses ok/info/warn but not err", () => {
  const cap = captureStdio();
  try {
    const rt = buildRuntime({ quiet: true }, {}, true);
    ok(rt, "ok-line");
    info(rt, "info-line");
    warn(rt, "warn-line");
    err(rt, "err-line");
    expect(cap.stderr).not.toContain("ok-line");
    expect(cap.stderr).not.toContain("info-line");
    expect(cap.stderr).not.toContain("warn-line");
    expect(cap.stderr).toContain("err-line");
  } finally {
    cap.restore();
  }
});

test("--plain swaps glyphs for words", () => {
  const cap = captureStdio();
  try {
    const rt = buildRuntime({ plain: true }, {}, true);
    ok(rt, "saved");
    err(rt, "boom");
    expect(cap.stderr).toContain("ok: saved");
    expect(cap.stderr).toContain("error: Error: boom");
    expect(cap.stderr).not.toContain("✓");
    expect(cap.stderr).not.toContain("✗");
  } finally {
    cap.restore();
  }
});

test("data() with text format invokes the renderer", () => {
  const cap = captureStdio();
  try {
    const rt = buildRuntime({}, {}, true);
    data(rt, { v: 1 }, () => "human-output");
    expect(cap.stdout).toBe("human-output\n");
  } finally {
    cap.restore();
  }
});

test("data() with json format produces parseable JSON", () => {
  const cap = captureStdio();
  try {
    const rt = buildRuntime({ format: "json" }, {}, true);
    data(rt, { theme: { variant: "dark" } }, () => "ignored");
    expect(JSON.parse(cap.stdout)).toEqual({ theme: { variant: "dark" } });
  } finally {
    cap.restore();
  }
});

test("usageError returns 2 and emits err + hint", () => {
  const cap = captureStdio();
  try {
    const rt = buildRuntime({}, {}, true);
    const code = usageError(rt, "bad input", "marchyo theme set dark");
    expect(code).toBe(2);
    expect(cap.stderr).toContain("Error: bad input");
    expect(cap.stderr).toContain("Try: marchyo theme set dark");
  } finally {
    cap.restore();
  }
});

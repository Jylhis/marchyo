import type { Runtime } from "./runtime.ts";

const GLYPH_OK = "✓";
const GLYPH_ERR = "✗";
const GLYPH_WARN = "!";
const GLYPH_INFO = "i";

// Returns the prefix string + the visible width used by `hint()` for
// continuation alignment. Plain mode swaps the glyph for a labeled prefix
// (jylhis/design §2.6) using the full word forms `error`/`warning`/`info`.
function prefix(rt: Runtime, glyph: string, word: string): string {
  return rt.plain ? `${word}: ` : `${glyph} `;
}

function writeStderr(line: string): void {
  process.stderr.write(line.endsWith("\n") ? line : line + "\n");
}

export function ok(rt: Runtime, msg: string): void {
  if (rt.quiet) return;
  writeStderr(`${prefix(rt, GLYPH_OK, "ok")}${msg}`);
}

export function err(rt: Runtime, msg: string): void {
  // Single signal per the spec: glyph or word, never both. Drop the
  // historical "Error: " literal so plain mode reads "error: msg" not
  // "error: Error: msg".
  writeStderr(`${prefix(rt, GLYPH_ERR, "error")}${msg}`);
}

export function warn(rt: Runtime, msg: string): void {
  if (rt.quiet) return;
  writeStderr(`${prefix(rt, GLYPH_WARN, "warning")}${msg}`);
}

export function info(rt: Runtime, msg: string): void {
  if (rt.quiet) return;
  writeStderr(`${prefix(rt, GLYPH_INFO, "info")}${msg}`);
}

// Continuation line under a preceding ok/err/warn/info; indented to align
// under the prefixed message body so multi-line context reads cleanly.
export function hint(rt: Runtime, msg: string): void {
  // Width of the prefix that the previous line used. We pad with spaces
  // so the hint sits under the message text, not under the level word.
  const prefWidth = rt.plain ? "warning: ".length : 2; // "✓ " width
  writeStderr(`${" ".repeat(prefWidth)}${msg}`);
}

export function debug(rt: Runtime, msg: string): void {
  if (rt.verbose > 0) writeStderr(`debug: ${msg}`);
}

// Print the user-requested data to stdout. JSON output bypasses textRender;
// text output uses the renderer. Always exactly one trailing newline.
export function data(
  rt: Runtime,
  value: unknown,
  textRender: () => string,
): void {
  const out =
    rt.format === "json"
      ? JSON.stringify(value)
      : textRender().replace(/\n*$/, "");
  process.stdout.write(out + "\n");
}

// Convenience wrapper: emit a usage error with a hint line, then signal
// an exit code of 2. Caller is responsible for actually exiting.
export function usageError(
  rt: Runtime,
  msg: string,
  suggestion?: string,
): 2 {
  err(rt, msg);
  if (suggestion) hint(rt, `Try: ${suggestion}`);
  return 2;
}

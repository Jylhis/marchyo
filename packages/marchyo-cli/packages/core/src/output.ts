import type { Runtime } from "./runtime.ts";

const GLYPH_OK = "✓"; // ✓
const GLYPH_ERR = "✗"; // ✗
const GLYPH_WARN = "!";
const GLYPH_INFO = "i";

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
  writeStderr(`${prefix(rt, GLYPH_ERR, "error")}Error: ${msg}`);
}

export function warn(rt: Runtime, msg: string): void {
  if (rt.quiet) return;
  writeStderr(`${prefix(rt, GLYPH_WARN, "warn")}Warning: ${msg}`);
}

export function info(rt: Runtime, msg: string): void {
  if (rt.quiet) return;
  writeStderr(`${prefix(rt, GLYPH_INFO, "info")}${msg}`);
}

export function hint(_rt: Runtime, msg: string): void {
  // Continuation line under an err()/warn(); always indented two spaces.
  writeStderr(`  ${msg}`);
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
    rt.format === "json" ? JSON.stringify(value) : textRender().replace(/\n*$/, "");
  process.stdout.write(out + "\n");
}

// Convenience wrapper: emit a usage error with a hint line, then signal
// an exit code of 2. Caller is responsible for actually exiting.
export function usageError(rt: Runtime, msg: string, suggestion?: string): 2 {
  err(rt, msg);
  if (suggestion) hint(rt, `Try: ${suggestion}`);
  return 2;
}

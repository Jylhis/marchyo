import { test, expect } from "bun:test";
import { buildRuntime } from "../src/runtime.ts";

test("default text format", () => {
  const rt = buildRuntime({}, {}, true);
  expect(rt.format).toBe("text");
});

test("--format json sets json", () => {
  const rt = buildRuntime({ format: "json" }, {}, true);
  expect(rt.format).toBe("json");
});

test("NO_COLOR env disables color", () => {
  const rt = buildRuntime({}, { NO_COLOR: "1" }, true);
  expect(rt.noColor).toBe(true);
});

test("--no-color flag disables color", () => {
  const rt = buildRuntime({ noColor: true }, {}, true);
  expect(rt.noColor).toBe(true);
});

test("--plain implies noColor and noAnimation", () => {
  const rt = buildRuntime({ plain: true }, {}, true);
  expect(rt.plain).toBe(true);
  expect(rt.noColor).toBe(true);
  expect(rt.noAnimation).toBe(true);
});

test("non-TTY disables color and animation by default", () => {
  const rt = buildRuntime({}, {}, false);
  expect(rt.noColor).toBe(true);
  expect(rt.noAnimation).toBe(true);
});

test("FORCE_COLOR keeps color on a non-TTY", () => {
  const rt = buildRuntime({}, { FORCE_COLOR: "1" }, false);
  expect(rt.noColor).toBe(false);
});

test("CLICOLOR_FORCE keeps color on a non-TTY", () => {
  const rt = buildRuntime({}, { CLICOLOR_FORCE: "1" }, false);
  expect(rt.noColor).toBe(false);
});

test("CI env enables noInput", () => {
  const rt = buildRuntime({}, { CI: "true" }, true);
  expect(rt.noInput).toBe(true);
});

test("verbose count is preserved", () => {
  expect(buildRuntime({ verbose: 0 }, {}, true).verbose).toBe(0);
  expect(buildRuntime({ verbose: 2 }, {}, true).verbose).toBe(2);
});

test("--color=never disables color even with FORCE_COLOR", () => {
  const rt = buildRuntime({ color: "never" }, { FORCE_COLOR: "1" }, true);
  expect(rt.noColor).toBe(true);
});

test("--color=always forces color on a non-TTY", () => {
  const rt = buildRuntime({ color: "always" }, {}, false);
  expect(rt.noColor).toBe(false);
  expect(rt.forceColor).toBe(true);
});

test("--color=auto follows TTY", () => {
  expect(buildRuntime({ color: "auto" }, {}, true).noColor).toBe(false);
  expect(buildRuntime({ color: "auto" }, {}, false).noColor).toBe(true);
});

test("NO_COLOR env beats --color=always", () => {
  const rt = buildRuntime({ color: "always" }, { NO_COLOR: "1" }, true);
  expect(rt.noColor).toBe(true);
});

test("TERM=dumb disables color and animation", () => {
  const rt = buildRuntime({}, { TERM: "dumb" }, true);
  expect(rt.noColor).toBe(true);
  expect(rt.noAnimation).toBe(true);
});

test("MARCHYO_DEBUG bumps verbose to 1 when no -v passed", () => {
  expect(buildRuntime({}, { MARCHYO_DEBUG: "1" }, true).verbose).toBe(1);
});

test("explicit -v wins over MARCHYO_DEBUG", () => {
  const rt = buildRuntime({ verbose: 3 }, { MARCHYO_DEBUG: "1" }, true);
  expect(rt.verbose).toBe(3);
});

test("buildRuntime throws FormatError on unsupported --format", async () => {
  const { FormatError } = await import("../src/runtime.ts");
  expect(() => buildRuntime({ format: "yaml" }, {}, true)).toThrow(FormatError);
  // The message must name the supported subset (§2.4).
  try {
    buildRuntime({ format: "yaml" }, {}, true);
  } catch (e) {
    expect((e as Error).message).toContain("text");
    expect((e as Error).message).toContain("json");
  }
});

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

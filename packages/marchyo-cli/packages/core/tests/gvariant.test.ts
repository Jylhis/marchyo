import { expect, test } from "bun:test";
import {
  dconfReadArgv,
  gvariantString,
  parseGvariantString,
  splitFontName,
} from "../src/desktop.ts";

test("gvariantString quotes and escapes", () => {
  expect(gvariantString("Inter 11")).toBe("'Inter 11'");
  expect(gvariantString("It's")).toBe("'It\\'s'");
});

test("parseGvariantString reads dconf output", () => {
  expect(parseGvariantString("'Inter 11'\n")).toBe("Inter 11");
  expect(parseGvariantString("''\n")).toBeNull();
  expect(parseGvariantString("")).toBeNull();
  expect(parseGvariantString(gvariantString("It's"))).toBe("It's");
});

test("splitFontName separates family and size", () => {
  expect(splitFontName("Inter 11")).toEqual({ family: "Inter", size: "11" });
  expect(splitFontName("Noto Sans Bold 10.5")).toEqual({
    family: "Noto Sans Bold",
    size: "10.5",
  });
  expect(splitFontName("Inter")).toEqual({ family: "Inter", size: null });
  expect(dconfReadArgv("/a/b")).toEqual(["dconf", "read", "/a/b"]);
});

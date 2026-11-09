import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";

const read = (rel) => readFileSync(new URL(rel, import.meta.url), "utf8");

const appPaths = [...read("./App.jsx").matchAll(/<Route\s+path="([^"]+)"/g)]
  .map((m) => m[1])
  .filter((p) => p !== "*")
  .map((p) => p.replace(/^\//, ""))
  .sort();

const staticSlugs = (() => {
  const src = read("../pages/os/[...slug].astro");
  const list = src.match(/return \[([^\]]*)\]/)[1];
  return [...list.matchAll(/'([^']*)'/g)].map((m) => m[1]).sort();
})();

test("every App.jsx route is prerendered by getStaticPaths", () => {
  expect(staticSlugs).toEqual(appPaths.filter((p) => p !== ""));
});

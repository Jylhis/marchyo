import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fillTemplate, tokenResolver, type Base16 } from "../src/matugen.ts";
import {
  APP_SURFACE_FILES,
  TEMPLATE_SURFACE_FILES,
  appSurfaceTexts,
} from "../src/theme-surfaces.ts";

type Parity = {
  base16: Base16;
  palette: Parameters<typeof tokenResolver>[0];
  expected: {
    surfaces: Record<string, string>;
    templateSurfaces: {
      templates: Record<string, string>;
      texts: Record<string, string>;
    };
  };
};
const parity = JSON.parse(
  readFileSync(join(import.meta.dir, "fixtures", "theme-parity.json"), "utf8"),
) as Parity;

describe("application surfaces", () => {
  const texts = appSurfaceTexts(parity.base16);

  for (const file of APP_SURFACE_FILES) {
    test(`${file} matches the Nix generator`, () => {
      expect(texts[file]).toBe(parity.expected.surfaces[file]!);
    });
  }

  test("the fixture carries no surface the CLI lacks", () => {
    expect(Object.keys(parity.expected.surfaces).sort()).toEqual(
      [...APP_SURFACE_FILES].sort(),
    );
  });
});

describe("template surfaces", () => {
  // lib/theme-surfaces.nix names the templates the build-variant dir ships;
  // `theme generate` must know how to fill every one of them.
  const nix = readFileSync(
    join(import.meta.dir, "..", "..", "..", "..", "..", "lib", "theme-surfaces.nix"),
    "utf8",
  );

  for (const file of ["btop.theme", "kitty.conf", "foot-theme.ini", "alacritty-theme.toml",
    "helix-theme.toml", "nvim-theme.lua", "emacs-theme.el"]) {
    test(`${file} is a CLI template surface and a Nix surface`, () => {
      expect(TEMPLATE_SURFACE_FILES as readonly string[]).toContain(file);
      expect(nix).toContain(`"${file}"`);
    });
  }

  const { templates, texts } = parity.expected.templateSurfaces;
  const resolve = tokenResolver(parity.palette, parity.base16);
  for (const file of Object.keys(texts)) {
    test(`${file} template fills to the Nix text`, () => {
      expect(fillTemplate(templates[file]!, resolve)).toBe(texts[file]!);
    });
  }

  test("the list has no duplicates", () => {
    expect(new Set(TEMPLATE_SURFACE_FILES).size).toBe(TEMPLATE_SURFACE_FILES.length);
  });
});

import { resolve } from "node:path";
import { nixEvalJson } from "./nix.ts";

export type OptionInfo = {
  path: string;
  type?: string;
  description?: string;
  default?: unknown;
  example?: unknown;
  declarations?: string[];
};

type RawOption = {
  _type?: string;
  type?: { name?: string; description?: string };
  description?: string;
  default?: { text?: string };
  example?: { text?: string };
  declarations?: string[];
};

// Map the Bun/Node process.arch to the short nixosConfiguration key the
// marchyo flake uses ("x86_64" / "aarch64"). Returns null on exotic arches
// so the Nix-side fallback (first available configuration) kicks in.
export function hostConfigKey(
  arch: string = process.arch,
): string | null {
  if (arch === "x64") return "x86_64";
  if (arch === "arm64") return "aarch64";
  return null;
}

// Characters safe to splice into the Nix expression below: an absolute
// path literal (no whitespace/quotes) and a bare attribute name. Anything
// else risks Nix-syntax injection or a confusing parse error.
const SAFE_NIX_PATH = /^\/[A-Za-z0-9._+/-]+$/;
const SAFE_ATTR_NAME = /^[A-Za-z_][A-Za-z0-9_'-]*$/;

// Build the eval expression. The configuration is chosen Nix-side: the
// explicit/detected name when the flake has it, otherwise the first
// available nixosConfiguration (with a builtins.trace warning on stderr,
// so a silent wrong-config eval is detectable).
export function optionsExpr(
  flakePath: string,
  configName: string | null = hostConfigKey(),
): string {
  if (!SAFE_NIX_PATH.test(flakePath)) {
    throw new Error(
      `flake path is not a plain absolute path, refusing to eval: "${flakePath}"`,
    );
  }
  const preferred = configName ?? "";
  if (preferred !== "" && !SAFE_ATTR_NAME.test(preferred)) {
    throw new Error(`invalid nixosConfiguration name: "${preferred}"`);
  }
  return `
  let
    flake = builtins.getFlake (toString ${flakePath});
    configs = flake.nixosConfigurations;
    names = builtins.attrNames configs;
    preferred = "${preferred}";
    fallback =
      if names == [] then throw "flake has no nixosConfigurations"
      else builtins.head names;
    name =
      if preferred == "" then fallback
      else if builtins.hasAttr preferred configs then preferred
      else builtins.trace
        "marchyo: nixosConfigurations.\${preferred} not found; using \${fallback}"
        fallback;
    sys = configs.\${name};
    walk = path: opt:
      if opt._type or "" == "option" then
        [ {
          inherit path;
          type = opt.type.description or opt.type.name or null;
          description = opt.description or null;
          declarations = opt.declarations or [];
          default = opt.defaultText or null;
          example = opt.example or null;
        } ]
      else if builtins.isAttrs opt then
        builtins.concatLists (builtins.map
          (n: walk (path + "." + n) (opt.\${n}))
          (builtins.attrNames opt))
      else [];
  in
    walk "marchyo" sys.options.marchyo
`;
}

export async function listOptions(
  flakePath: string,
  configName?: string,
): Promise<OptionInfo[]> {
  // Normalize before the safety check so relative paths ("." from the
  // dev CLI's --repo flag) still work.
  const expr = `(${optionsExpr(resolve(flakePath), configName ?? hostConfigKey())})`;
  const raw = await nixEvalJson<RawOption[]>(expr);
  return raw.map((o) => {
    const r = o as RawOption & { path: string };
    return {
      path: r.path,
      type: r.type?.description ?? r.type?.name ?? undefined,
      description: r.description ?? undefined,
      default: r.default,
      example: r.example,
      declarations: r.declarations ?? undefined,
    };
  });
}

export function searchOptions(
  options: OptionInfo[],
  query: string,
): OptionInfo[] {
  const q = query.toLowerCase();
  return options
    .map((opt) => ({
      opt,
      score: scoreOption(opt, q),
    }))
    .filter((s) => s.score > 0)
    .sort((a, b) => b.score - a.score)
    .map((s) => s.opt);
}

function scoreOption(opt: OptionInfo, q: string): number {
  const path = opt.path.toLowerCase();
  if (path.includes(q)) return 100 + (q.length / path.length) * 50;
  if (opt.description?.toLowerCase().includes(q)) return 25;
  return 0;
}

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

// Build the eval expression. The configuration is chosen Nix-side: the
// explicit/detected name when the flake has it, otherwise the first
// available nixosConfiguration (so the eval works on any host arch and on
// flakes that name their configurations differently).
export function optionsExpr(
  flakePath: string,
  configName: string | null = hostConfigKey(),
): string {
  const preferred = configName ?? "";
  return `
  let
    flake = builtins.getFlake (toString ${flakePath});
    configs = flake.nixosConfigurations;
    names = builtins.attrNames configs;
    preferred = "${preferred}";
    name =
      if preferred != "" && builtins.hasAttr preferred configs then preferred
      else if names != [] then builtins.head names
      else throw "flake at ${flakePath} has no nixosConfigurations";
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
  const expr = `(${optionsExpr(flakePath, configName ?? hostConfigKey())})`;
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

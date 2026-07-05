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

const OPTIONS_EXPR = `
  let
    flake = builtins.getFlake (toString ./.);
    sys = flake.nixosConfigurations.x86_64;
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

export async function listOptions(flakePath: string): Promise<OptionInfo[]> {
  const expr = `(${OPTIONS_EXPR.replace("./.", flakePath)})`;
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

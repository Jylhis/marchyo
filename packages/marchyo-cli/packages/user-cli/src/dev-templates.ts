import bun from "../templates/dev/bun.nix" with { type: "text" };
import clojure from "../templates/dev/clojure.nix" with { type: "text" };
import deno from "../templates/dev/deno.nix" with { type: "text" };
import devenvYaml from "../templates/dev/devenv-yaml.txt" with { type: "text" };
import dotnet from "../templates/dev/dotnet.nix" with { type: "text" };
import elixir from "../templates/dev/elixir.nix" with { type: "text" };
import envrc from "../templates/dev/envrc.txt" with { type: "text" };
import go from "../templates/dev/go.nix" with { type: "text" };
import java from "../templates/dev/java.nix" with { type: "text" };
import node from "../templates/dev/node.nix" with { type: "text" };
import ocaml from "../templates/dev/ocaml.nix" with { type: "text" };
import php from "../templates/dev/php.nix" with { type: "text" };
import python from "../templates/dev/python.nix" with { type: "text" };
import ruby from "../templates/dev/ruby.nix" with { type: "text" };
import rust from "../templates/dev/rust.nix" with { type: "text" };
import scala from "../templates/dev/scala.nix" with { type: "text" };
import zig from "../templates/dev/zig.nix" with { type: "text" };

export const LANGUAGE_TEMPLATES: Record<string, string> = {
  bun,
  clojure,
  deno,
  dotnet,
  elixir,
  go,
  java,
  node,
  ocaml,
  php,
  python,
  ruby,
  rust,
  scala,
  zig,
};

export const DEVENV_YAML: string = devenvYaml;
export const ENVRC: string = envrc;

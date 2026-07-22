// Single source of truth for the CLI version: the monorepo package.json.
// Bundled statically by `bun build --compile`; package.nix reads the same
// field at eval time, so all three surfaces can never drift.
import pkg from "../../../package.json";

export const VERSION: string = pkg.version;

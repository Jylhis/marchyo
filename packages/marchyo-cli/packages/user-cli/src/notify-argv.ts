// `marchyo notify` reads its own flags (--exec, --action, -u ...), which
// commander would take for its own. cli.tsx hands it the words after `notify`
// untouched; this finds that point even when global options come first.

const GLOBAL_VALUE = new Set(["-F", "--format", "--color"]);
const GLOBAL_FLAG = new Set(["--json", "--no-color", "--plain", "--no-animation", "--no-input", "--quiet", "--verbose"]);

export type NotifySplit = { globals: string[]; rest: string[] };

// argv without the node and script words. Null when the command is not
// `notify`, or an option before it is not a global one (commander then decides).
export function splitNotifyArgv(argv: string[]): NotifySplit | null {
  const globals: string[] = [];
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i]!;
    if (arg === "notify") return { globals, rest: argv.slice(i + 1) };
    if (!arg.startsWith("-")) return null;
    const name = arg.includes("=") ? arg.slice(0, arg.indexOf("=")) : arg;
    if (GLOBAL_VALUE.has(name) && arg.includes("=")) {
      globals.push(arg);
    } else if (GLOBAL_VALUE.has(name)) {
      if (i + 1 >= argv.length) return null;
      globals.push(arg, argv[++i]!);
    } else if (/^-F./.test(arg) || GLOBAL_FLAG.has(arg) || /^-[qv]+$/.test(arg)) {
      globals.push(arg);
    } else {
      return null;
    }
  }
  return null;
}

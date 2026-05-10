import React, { useEffect, useState } from "react";
import { render, Box, Text, useApp, useInput, useStdout } from "ink";
import Spinner from "ink-spinner";
import {
  listOptions,
  searchOptions,
  err,
  info,
  type OptionInfo,
  type Runtime,
} from "@marchyo/core";

type Phase =
  | { kind: "loading" }
  | { kind: "error"; message: string }
  | { kind: "results"; matches: OptionInfo[] };

const MIN_COLS = 80;
const BULLET = "›";

function ResultsView({
  rt,
  query,
  phase,
  showHelp,
}: {
  rt: Runtime;
  query: string;
  phase: Phase;
  showHelp: boolean;
}) {
  if (phase.kind === "loading") {
    return (
      <Box>
        <Text color={rt.noColor ? undefined : "cyan"}>
          <Spinner type="dots" />
        </Text>
        <Text> evaluating marchyo.* options ...</Text>
      </Box>
    );
  }
  if (phase.kind === "error") {
    return (
      <Box flexDirection="column">
        <Text color={rt.noColor ? undefined : "red"}>✗ {phase.message}</Text>
        <FooterHint rt={rt} showHelp={showHelp} />
      </Box>
    );
  }
  if (phase.matches.length === 0) {
    return (
      <Box flexDirection="column">
        <Text>i no options matched '{query}'.</Text>
        <FooterHint rt={rt} showHelp={showHelp} />
      </Box>
    );
  }
  return (
    <Box flexDirection="column">
      <Text bold>
        {phase.matches.length} option
        {phase.matches.length === 1 ? "" : "s"} matching '{query}':
      </Text>
      {phase.matches.slice(0, 25).map((opt) => (
        <Box key={opt.path} flexDirection="column" marginTop={1}>
          <Text bold color={rt.noColor ? undefined : "cyan"}>
            {rt.plain ? "" : `${BULLET} `}
            {opt.path}
          </Text>
          {opt.type ? (
            <Text>
              <Text color={rt.noColor ? undefined : "gray"}>  type: </Text>
              {opt.type}
            </Text>
          ) : null}
          {opt.description ? (
            <Text>  {firstLine(opt.description)}</Text>
          ) : null}
        </Box>
      ))}
      {phase.matches.length > 25 ? (
        <Box marginTop={1}>
          <Text dimColor>(showing first 25 of {phase.matches.length})</Text>
        </Box>
      ) : null}
      <FooterHint rt={rt} showHelp={showHelp} />
    </Box>
  );
}

function FooterHint({
  rt,
  showHelp,
}: {
  rt: Runtime;
  showHelp: boolean;
}) {
  if (showHelp) {
    return (
      <Box flexDirection="column" marginTop={1}>
        <Text dimColor>──────────── help ────────────</Text>
        <Text dimColor>?    toggle this help</Text>
        <Text dimColor>q    quit</Text>
        <Text dimColor>Esc  quit</Text>
        <Text dimColor>C-c  quit</Text>
      </Box>
    );
  }
  return (
    <Box marginTop={1}>
      <Text dimColor>
        {rt.plain ? "" : "  "}? help · q quit · Esc quit
      </Text>
    </Box>
  );
}

function firstLine(s: string): string {
  const trimmed = s.trim();
  const nl = trimmed.indexOf("\n");
  return nl === -1 ? trimmed : trimmed.slice(0, nl);
}

function App({
  rt,
  query,
  repoPath,
}: {
  rt: Runtime;
  query: string;
  repoPath: string;
}) {
  const [phase, setPhase] = useState<Phase>({ kind: "loading" });
  const [showHelp, setShowHelp] = useState(false);
  const { exit } = useApp();
  const { stdout } = useStdout();

  // Note: useInput is wired against stdin. For our render-to-stderr setup
  // stdin is the user's terminal so keyboard handling works as expected.
  useInput((input, key) => {
    if (input === "?") setShowHelp((s) => !s);
    else if (input === "q" || key.escape) exit();
    // Ctrl-C is handled by Ink internally as exit.
  });

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const all = await listOptions(repoPath);
        const matches = searchOptions(all, query);
        if (!cancelled) {
          setPhase({ kind: "results", matches });
          // On non-interactive contexts (no useInput keypress will arrive),
          // exit immediately so the process doesn't hang.
          if (!stdout.isTTY) exit();
        }
      } catch (e) {
        if (!cancelled) {
          setPhase({
            kind: "error",
            message: e instanceof Error ? e.message : String(e),
          });
          if (!stdout.isTTY) exit();
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [query, repoPath, exit, stdout.isTTY]);

  return <ResultsView rt={rt} query={query} phase={phase} showHelp={showHelp} />;
}

function renderPlainText(query: string, matches: OptionInfo[]): string {
  if (matches.length === 0) return `i no options matched '${query}'.`;
  const lines: string[] = [];
  lines.push(
    `${matches.length} option${matches.length === 1 ? "" : "s"} matching '${query}':`,
  );
  for (const opt of matches.slice(0, 25)) {
    lines.push("");
    lines.push(opt.path);
    if (opt.type) lines.push(`  type: ${opt.type}`);
    if (opt.description) lines.push(`  ${firstLine(opt.description)}`);
  }
  if (matches.length > 25) {
    lines.push("");
    lines.push(`(showing first 25 of ${matches.length})`);
  }
  return lines.join("\n");
}

export async function runOptionsSearch(
  rt: Runtime,
  query: string,
  repoPath: string,
): Promise<number> {
  // Machine / a11y / non-TTY paths skip Ink entirely: data goes to stdout
  // (so it's pipeable), progress to stderr, no escape sequences leak.
  if (rt.format !== "text" || rt.plain || rt.noAnimation) {
    info(rt, "evaluating marchyo.* options ...");
    try {
      const all = await listOptions(repoPath);
      const matches = searchOptions(all, query);
      if (rt.format === "json") {
        process.stdout.write(JSON.stringify({ query, matches }) + "\n");
      } else {
        process.stdout.write(renderPlainText(query, matches) + "\n");
      }
      return 0;
    } catch (e) {
      err(rt, e instanceof Error ? e.message : String(e));
      return 1;
    }
  }

  // Interactive TTY path: Ink renders to stdout (UI IS the data here).
  // We only reach this branch when stdout is a TTY (noAnimation guards
  // above), so escapes never end up in a redirected file.
  // Below 80 columns we fall back to the plain renderer (§3.2 min size).
  const cols = process.stdout.columns ?? MIN_COLS;
  if (cols < MIN_COLS) {
    info(rt, `terminal narrower than ${MIN_COLS} cols; using plain layout`);
    try {
      const all = await listOptions(repoPath);
      const matches = searchOptions(all, query);
      process.stdout.write(renderPlainText(query, matches) + "\n");
      return 0;
    } catch (e) {
      err(rt, e instanceof Error ? e.message : String(e));
      return 1;
    }
  }

  const { waitUntilExit } = render(
    <App rt={rt} query={query} repoPath={repoPath} />,
    { exitOnCtrlC: true },
  );
  await waitUntilExit();
  return 0;
}

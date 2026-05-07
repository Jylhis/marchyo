import React, { useEffect, useState } from "react";
import { render, Box, Text } from "ink";
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

function ResultsView({
  rt,
  query,
  phase,
}: {
  rt: Runtime;
  query: string;
  phase: Phase;
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
      <Text color={rt.noColor ? undefined : "red"}>
        ✗ Error: {phase.message}
      </Text>
    );
  }
  if (phase.matches.length === 0) {
    return <Text>i no options matched '{query}'.</Text>;
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
            › {opt.path}
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
  onDone,
}: {
  rt: Runtime;
  query: string;
  repoPath: string;
  onDone: () => void;
}) {
  const [phase, setPhase] = useState<Phase>({ kind: "loading" });

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const all = await listOptions(repoPath);
        const matches = searchOptions(all, query);
        if (!cancelled) {
          setPhase({ kind: "results", matches });
          onDone();
        }
      } catch (e) {
        if (!cancelled) {
          setPhase({
            kind: "error",
            message: e instanceof Error ? e.message : String(e),
          });
          onDone();
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [query, repoPath, onDone]);

  return <ResultsView rt={rt} query={query} phase={phase} />;
}

function renderPlainText(query: string, matches: OptionInfo[]): string {
  if (matches.length === 0) return `i no options matched '${query}'.`;
  const lines: string[] = [];
  lines.push(
    `${matches.length} option${matches.length === 1 ? "" : "s"} matching '${query}':`,
  );
  for (const opt of matches.slice(0, 25)) {
    lines.push("");
    lines.push(`› ${opt.path}`);
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
  // JSON / plain / non-TTY paths skip Ink entirely so output is scriptable
  // and does not leak ANSI escapes.
  if (rt.format === "json" || rt.plain || rt.noAnimation) {
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

  return await new Promise<number>((resolve) => {
    const { unmount, waitUntilExit } = render(
      <App
        rt={rt}
        query={query}
        repoPath={repoPath}
        onDone={() => {
          // Allow Ink to flush the final frame, then unmount.
          setTimeout(() => unmount(), 0);
        }}
      />,
    );
    waitUntilExit().then(() => resolve(0));
  });
}

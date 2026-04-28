import React, { useEffect, useState } from "react";
import { render, Box, Text } from "ink";
import Spinner from "ink-spinner";
import { listOptions, searchOptions, type OptionInfo } from "@marchyo/core";

type Phase =
  | { kind: "loading" }
  | { kind: "error"; message: string }
  | { kind: "results"; matches: OptionInfo[] };

function ResultsView({ query, phase }: { query: string; phase: Phase }) {
  if (phase.kind === "loading") {
    return (
      <Box>
        <Text color="cyan">
          <Spinner type="dots" />
        </Text>
        <Text> evaluating marchyo.* options ...</Text>
      </Box>
    );
  }
  if (phase.kind === "error") {
    return <Text color="red">error: {phase.message}</Text>;
  }
  if (phase.matches.length === 0) {
    return <Text>no options matched '{query}'.</Text>;
  }
  return (
    <Box flexDirection="column">
      <Text bold>
        {phase.matches.length} option{phase.matches.length === 1 ? "" : "s"} matching '{query}':
      </Text>
      {phase.matches.slice(0, 25).map((opt) => (
        <Box key={opt.path} flexDirection="column" marginTop={1}>
          <Text bold color="cyan">
            {opt.path}
          </Text>
          {opt.type ? (
            <Text>
              <Text color="gray">type: </Text>
              {opt.type}
            </Text>
          ) : null}
          {opt.description ? (
            <Text>{firstLine(opt.description)}</Text>
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

function App({ query, repoPath }: { query: string; repoPath: string }) {
  const [phase, setPhase] = useState<Phase>({ kind: "loading" });

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const all = await listOptions(repoPath);
        const matches = searchOptions(all, query);
        if (!cancelled) setPhase({ kind: "results", matches });
      } catch (err) {
        if (!cancelled) {
          setPhase({
            kind: "error",
            message: err instanceof Error ? err.message : String(err),
          });
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [query, repoPath]);

  return <ResultsView query={query} phase={phase} />;
}

export async function runOptionsSearch(
  query: string,
  repoPath: string,
): Promise<void> {
  const { waitUntilExit } = render(
    <App query={query} repoPath={repoPath} />,
  );
  await waitUntilExit();
}

import React from "react";
import { render, Box, Text } from "ink";
import {
  readState,
  detectFlake,
  getCurrentGenerationNumber,
  getCurrentGenerationDate,
  type State,
  type FlakeLocation,
} from "@marchyo/core";

type StatusData = {
  state: State;
  flake: FlakeLocation | null;
  generation: number | null;
  generationDate: Date | null;
};

function StatusView({ data }: { data: StatusData }) {
  return (
    <Box flexDirection="column" paddingX={1}>
      <Box marginBottom={1}>
        <Text bold color="cyan">
          Marchyo status
        </Text>
      </Box>

      <Section title="System">
        <Row label="Generation" value={data.generation?.toString() ?? "unknown"} />
        <Row
          label="Last activated"
          value={data.generationDate?.toISOString() ?? "unknown"}
        />
        <Row
          label="Flake"
          value={
            data.flake
              ? `${data.flake.path} (${data.flake.source})`
              : "not detected"
          }
        />
      </Section>

      <Section title="CLI state (/etc/marchyo/cli-state.json)">
        <Row
          label="theme.variant"
          value={data.state.theme?.variant ?? "(unset, using flake value)"}
        />
      </Section>

      <Box marginTop={1}>
        <Text dimColor>
          Run 'marchyo theme dark|light' to change theme; 'marchyo rebuild' to
          apply.
        </Text>
      </Box>
    </Box>
  );
}

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <Box flexDirection="column" marginBottom={1}>
      <Text bold>{title}</Text>
      <Box flexDirection="column" paddingLeft={2}>
        {children}
      </Box>
    </Box>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <Box>
      <Box width={20}>
        <Text color="gray">{label}</Text>
      </Box>
      <Text>{value}</Text>
    </Box>
  );
}

export async function runStatus(): Promise<void> {
  const [state, flake, generation, generationDate] = await Promise.all([
    readState().catch(() => ({}) as State),
    detectFlake(),
    getCurrentGenerationNumber(),
    getCurrentGenerationDate(),
  ]);

  const { waitUntilExit } = render(
    <StatusView
      data={{ state, flake, generation, generationDate }}
    />,
  );
  await waitUntilExit();
}

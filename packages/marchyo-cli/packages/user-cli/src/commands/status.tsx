import React from "react";
import { render, Box, Text } from "ink";
import {
  readState,
  detectFlake,
  getCurrentGenerationNumber,
  getCurrentGenerationDate,
  type State,
  type FlakeLocation,
  type Runtime,
} from "@marchyo/core";

type StatusData = {
  state: State;
  flake: FlakeLocation | null;
  generation: number | null;
  generationDate: Date | null;
};

const GLYPH_OK = "✓";
const GLYPH_WARN = "!";
const GLYPH_INFO = "i";

function glyph(rt: Runtime, ok: boolean): string {
  if (rt.plain) return ok ? "[ok]" : "[!]";
  return ok ? GLYPH_OK : GLYPH_WARN;
}

function StatusView({ rt, d }: { rt: Runtime; d: StatusData }) {
  const flakeOK = d.flake !== null;
  return (
    <Box flexDirection="column" paddingX={1}>
      <Box marginBottom={1}>
        <Text bold color={rt.noColor ? undefined : "cyan"}>
          Marchyo status
        </Text>
      </Box>

      <Section title="System" rt={rt}>
        <Row
          rt={rt}
          ok={d.generation !== null}
          label="Generation"
          value={d.generation?.toString() ?? "unknown"}
        />
        <Row
          rt={rt}
          ok={d.generationDate !== null}
          label="Last activated"
          value={d.generationDate?.toISOString() ?? "unknown"}
        />
        <Row
          rt={rt}
          ok={flakeOK}
          label="Flake"
          value={
            d.flake
              ? `${d.flake.path} (${d.flake.source})`
              : "not detected"
          }
        />
      </Section>

      <Section title="CLI state (/etc/marchyo/cli-state.json)" rt={rt}>
        <Row
          rt={rt}
          ok={d.state.theme?.variant !== undefined}
          label="theme.variant"
          value={d.state.theme?.variant ?? "(unset, using flake value)"}
        />
      </Section>

      <Box marginTop={1}>
        <Text dimColor>
          {GLYPH_INFO} marchyo theme set dark|light · marchyo rebuild
        </Text>
      </Box>
    </Box>
  );
}

function Section({
  title,
  rt,
  children,
}: {
  title: string;
  rt: Runtime;
  children: React.ReactNode;
}) {
  return (
    <Box flexDirection="column" marginBottom={1}>
      <Text bold color={rt.noColor ? undefined : "white"}>
        {title}
      </Text>
      <Box flexDirection="column" paddingLeft={2}>
        {children}
      </Box>
    </Box>
  );
}

function Row({
  rt,
  ok,
  label,
  value,
}: {
  rt: Runtime;
  ok: boolean;
  label: string;
  value: string;
}) {
  return (
    <Box>
      <Box width={3}>
        <Text color={rt.noColor ? undefined : ok ? "green" : "yellow"}>
          {glyph(rt, ok)}
        </Text>
      </Box>
      <Box width={20}>
        <Text color={rt.noColor ? undefined : "gray"}>{label}</Text>
      </Box>
      <Text>{value}</Text>
    </Box>
  );
}

function renderPlainText(d: StatusData): string {
  const flake = d.flake
    ? `${d.flake.path} (${d.flake.source})`
    : "not detected";
  return [
    `Marchyo status`,
    ``,
    `System`,
    `  Generation:      ${d.generation ?? "unknown"}`,
    `  Last activated:  ${d.generationDate?.toISOString() ?? "unknown"}`,
    `  Flake:           ${flake}`,
    ``,
    `CLI state (/etc/marchyo/cli-state.json)`,
    `  theme.variant:   ${d.state.theme?.variant ?? "(unset)"}`,
  ].join("\n");
}

export async function runStatus(rt: Runtime): Promise<number> {
  const [state, flake, generation, generationDate] = await Promise.all([
    readState().catch(() => ({}) as State),
    detectFlake(),
    getCurrentGenerationNumber(),
    getCurrentGenerationDate(),
  ]);

  const d: StatusData = { state, flake, generation, generationDate };

  if (rt.format === "json") {
    process.stdout.write(
      JSON.stringify({
        generation,
        generationDate: generationDate?.toISOString() ?? null,
        flake: flake
          ? { path: flake.path, source: flake.source }
          : null,
        theme: { variant: state.theme?.variant ?? null },
      }) + "\n",
    );
    return 0;
  }

  if (rt.plain || rt.noAnimation) {
    process.stdout.write(renderPlainText(d) + "\n");
    return 0;
  }

  const { waitUntilExit } = render(<StatusView rt={rt} d={d} />);
  await waitUntilExit();
  return 0;
}

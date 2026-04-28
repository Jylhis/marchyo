import { z } from "zod";

// JSON sidecar at /etc/marchyo/cli-state.json. A NixOS module reads this file
// and merges values into config.marchyo.* with lib.mkDefault priority, so a
// hand-written flake configuration always wins.
export const STATE_PATH = "/etc/marchyo/cli-state.json";

export const ThemeVariant = z.enum(["dark", "light"]);
export type ThemeVariant = z.infer<typeof ThemeVariant>;

export const StateSchema = z
  .object({
    theme: z
      .object({
        variant: ThemeVariant.optional(),
      })
      .optional(),
    _flake: z
      .object({
        path: z.string().optional(),
      })
      .optional(),
  })
  .strict();

export type State = z.infer<typeof StateSchema>;

export const EMPTY_STATE: State = {};

export async function readState(path: string = STATE_PATH): Promise<State> {
  const file = Bun.file(path);
  if (!(await file.exists())) return EMPTY_STATE;
  const raw = await file.text();
  if (raw.trim() === "") return EMPTY_STATE;
  const parsed = JSON.parse(raw);
  return StateSchema.parse(parsed);
}

export async function writeState(
  next: State,
  path: string = STATE_PATH,
): Promise<void> {
  const validated = StateSchema.parse(next);
  const serialized = JSON.stringify(validated, null, 2) + "\n";
  await Bun.write(path, serialized);
}

export function mergeState(prev: State, patch: State): State {
  return {
    ...prev,
    ...patch,
    theme: { ...prev.theme, ...patch.theme },
    _flake: { ...prev._flake, ...patch._flake },
  };
}

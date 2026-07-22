import { z } from "zod";
import { homedir, userInfo } from "node:os";
import { join } from "node:path";

// State priority chain (jylhis/design §2.5.2): defaults < system < user.
// Read merges system+user (user wins). Write goes to whichever location
// the current process can write to: root → system, otherwise → user.
export const SYSTEM_STATE_PATH = "/etc/marchyo/cli-state.json";

export function userStatePath(env: NodeJS.ProcessEnv = process.env): string {
  const xdg = env.XDG_CONFIG_HOME;
  const base = xdg && xdg !== "" ? xdg : join(homedir(), ".config");
  return join(base, "marchyo", "state.json");
}

export const ThemeVariant = z.enum(["dark", "light"]);
export type ThemeVariant = z.infer<typeof ThemeVariant>;

export const StateSchema = z
  .object({
    theme: z
      .object({
        variant: ThemeVariant.optional(),
        // base16-schemes name (maps to marchyo.theme.scheme); absent when
        // a Jylhis variant is selected.
        scheme: z.string().optional(),
      })
      .optional(),
    graphics: z
      .object({
        prime: z
          .object({
            enable: z.boolean().optional(),
          })
          .optional(),
      })
      .optional(),
    // Coarse feature flags (marchyo install/remove <feature>).
    desktop: z.object({ enable: z.boolean().optional() }).optional(),
    development: z.object({ enable: z.boolean().optional() }).optional(),
    media: z.object({ enable: z.boolean().optional() }).optional(),
    office: z.object({ enable: z.boolean().optional() }).optional(),
    dictation: z.object({ enable: z.boolean().optional() }).optional(),
    webapps: z
      .object({
        enable: z.boolean().optional(),
        // Additive PWA list (marchyo webapp add/rm) — maps to
        // marchyo.webapps.extraApps so the default set is never replaced.
        extraApps: z
          .array(
            z
              .object({
                name: z.string(),
                url: z.string(),
                icon: z.string().optional(),
                key: z.string().optional(),
                modifiers: z.string().optional(),
              })
              .strict(),
          )
          .optional(),
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

async function readOne(path: string): Promise<State> {
  const file = Bun.file(path);
  if (!(await file.exists())) return EMPTY_STATE;
  const raw = await file.text();
  if (raw.trim() === "") return EMPTY_STATE;
  return StateSchema.parse(JSON.parse(raw));
}

// Read both system and user state and merge. User overlays system; deep
// for nested objects so a user theme variant overrides system theme variant
// without clobbering an unrelated system-set field.
export async function readState(
  systemPath: string = SYSTEM_STATE_PATH,
  userPath: string = userStatePath(),
): Promise<State> {
  const [sys, usr] = await Promise.all([readOne(systemPath), readOne(userPath)]);
  return mergeState(sys, usr);
}

// Write to the appropriate file based on whether the caller can plausibly
// write to the system path. Resolution: explicit `path` arg wins; root user
// → system path; otherwise user path (and creates the directory).
export async function writeState(
  next: State,
  opts: { path?: string } = {},
): Promise<{ path: string }> {
  const validated = StateSchema.parse(next);
  const isRoot = userInfo().uid === 0;
  const path = opts.path ?? (isRoot ? SYSTEM_STATE_PATH : userStatePath());
  const serialized = JSON.stringify(validated, null, 2) + "\n";
  await Bun.write(path, serialized);
  return { path };
}

export function mergeState(prev: State, patch: State): State {
  const merged: State = { ...prev, ...patch };
  if (prev.theme || patch.theme) {
    merged.theme = { ...prev.theme, ...patch.theme };
  }
  if (prev.graphics || patch.graphics) {
    merged.graphics = { ...prev.graphics, ...patch.graphics };
  }
  if (prev.webapps || patch.webapps) {
    merged.webapps = { ...prev.webapps, ...patch.webapps };
  }
  if (prev._flake || patch._flake) {
    merged._flake = { ...prev._flake, ...patch._flake };
  }
  return merged;
}

#!/usr/bin/env bun
import { Command, Option } from "commander";
import {
  buildRuntime,
  FormatError,
  err,
  hint,
  type Runtime,
  type RuntimeFlags,
} from "@marchyo/core";
import { runStatus } from "./commands/status.tsx";
import {
  runBgList,
  runBgNext,
  runBgSet,
  runThemeGenerate,
  runThemeGet,
  runThemeList,
  runThemeNext,
  runThemeSet,
} from "./commands/theme.ts";
import { runRebuild } from "./commands/rebuild.ts";
import { runUpdate } from "./commands/update.ts";
import { runUpgrade } from "./commands/upgrade.ts";
import { runRollback } from "./commands/rollback.ts";
import { runGc } from "./commands/gc.ts";
import { runDiff } from "./commands/diff.ts";
import { runDebug } from "./commands/debug.ts";
import { runDoctor } from "./commands/doctor.ts";
import {
  runShellBar,
  runShellBarState,
  runShellDismiss,
  runShellNotifyKeys,
  runShellDnd,
  runShellDndState,
  runShellGallery,
  runShellLauncher,
  runShellLock,
  runShellLockState,
  runShellOverview,
  runShellPanel,
  runShellReload,
} from "./commands/shell.ts";
import { runBrightness, runVolume } from "./commands/media.ts";
import { runRuntimeRestore, runRuntimeStatus } from "./commands/runtime.ts";
import { runToggle } from "./commands/toggle.ts";
import {
  runThemeBarBackground,
  runThemeBarPosition,
  runThemeCorners,
  runThemeGaps,
  runThemeIcons,
  runThemeTransparency,
} from "./commands/appearance.ts";
import {
  runBarBackground,
  runBarList,
  runBarMove,
  runBarPosition,
  runBarPut,
  runBarRemove,
  runBarReset,
  runBarSet,
} from "./commands/bar.ts";
import { runWindow } from "./commands/window.ts";
import {
  runCaptureColor,
  runCaptureOcr,
  runCaptureRecord,
  runCaptureScreenshot,
} from "./commands/capture.ts";
import { runKeybindings, runMenu, runMenuInput, runMenuSelect } from "./commands/menu.ts";
import {
  runFocusOrLaunch,
  runLaunch,
  runMonitorClamshell,
  runMonitorLaptopToggle,
  runMonitorReset,
  runMonitorSave,
  runMonitorScaleCycle,
  runMonitorWorkspacesReset,
  runZoom,
} from "./commands/launch.ts";
import {
  runHibernate,
  runLock,
  runLogout,
  runPowerprofile,
  runReboot,
  runRebootFirmware,
  runShutdown,
  runSuspend,
} from "./commands/power.ts";
import {
  runInfo,
  runReminderClear,
  runReminderSet,
  runReminderShow,
  runShare,
  runTranscode,
} from "./commands/utilities.ts";
import {
  type FontKind,
  runFontCurrent,
  runFontList,
  runFontSet,
} from "./commands/font.ts";
import { runDictation } from "./commands/dictation.ts";
import { runLanguage } from "./commands/language.ts";
import {
  runInstall,
  runRemove,
  runSecurityEnroll,
  runWebappAdd,
  runWebappRm,
} from "./commands/declarative.ts";
import {
  runPluginAdd,
  runPluginList,
  runPluginRemove,
  runPluginUpdate,
  runPluginValidate,
} from "./commands/plugin.ts";
import { runCompletion } from "./commands/completion.ts";
import { runNetworkPortal } from "./commands/network.ts";
import { runNotify } from "./commands/notify.ts";
import { splitNotifyArgv } from "./notify-argv.ts";
import { runWhatsNew } from "./commands/whatsnew.ts";
import { runSetup, runSetupFix } from "./commands/setup.ts";
import { attachExamples } from "./examples.ts";
import { VERSION } from "./version.ts";

const program = new Command();

program
  .name("marchyo")
  .description("Marchyo user CLI — inspect and manage your Marchyo install")
  .version(VERSION)
  // --format accepts the canonical jylhis vocabulary; only text|json are
  // implemented today. Any other value rejects with a usage error naming
  // the supported subset (validated in core/runtime.ts:parseFormat).
  .option("-F, --format <fmt>", "output format (text | json)", "text")
  .option("--json", "alias for --format json")
  .addOption(
    new Option("--color <when>", "color usage")
      .choices(["auto", "always", "never"])
      .default("auto"),
  )
  .option("--no-color", "disable color (alias for --color=never)")
  .option("--plain", "strip color, glyphs, and animation (a11y mode)")
  .option("--no-animation", "disable spinners and progress animation")
  .option("--no-input", "disable interactive prompts (also auto-set under CI=1)")
  .option("-q, --quiet", "suppress non-error output")
  .option(
    "-v, --verbose",
    "increase verbosity (repeatable; also bumped by MARCHYO_DEBUG=1)",
    (_, prev: number) => prev + 1,
    0,
  );

program.addHelpText(
  "after",
  `
Examples:
  $ marchyo status
  $ marchyo theme set nord
  $ marchyo theme set dark --apply
  $ marchyo theme get --format json
  $ marchyo rebuild --dry-run

Color: honors NO_COLOR, CLICOLOR_FORCE, FORCE_COLOR, --color, --no-color.
       --plain is a stronger a11y switch (no color, no glyphs, no animation).
`,
);

function rt(): Runtime {
  const o = program.opts<RuntimeFlags & { json?: boolean }>();
  // --json is sugar for --format json. If both are set, --format wins
  // (more specific/explicit).
  const flags: RuntimeFlags = {
    ...o,
    format: o.format === "text" && o.json ? "json" : o.format,
  };
  try {
    return buildRuntime(flags);
  } catch (e) {
    if (e instanceof FormatError) {
      process.stderr.write(`✗ ${e.message}\n`);
      process.exit(2);
    }
    throw e;
  }
}

program
  .command("status")
  .description("Show current Marchyo configuration and system info")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo status
  $ marchyo status --format json | jq .theme.variant
`,
  )
  .action(async () => {
    process.exit(await runStatus(rt()));
  });

const theme = program
  .command("theme")
  .description("Inspect and switch Marchyo themes at runtime");

theme
  .command("list")
  .description("List switchable themes (marchyo.theme.themes)")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo theme list
  $ marchyo theme list --format json
`,
  )
  .action(async () => {
    process.exit(await runThemeList(rt()));
  });

theme
  .command("get")
  .description("Print the active theme")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo theme get
  $ marchyo theme get --format json
`,
  )
  .action(async () => {
    process.exit(await runThemeGet(rt()));
  });

theme
  .command("set")
  .description("Switch the theme live (persist with --apply)")
  .argument("<name>", "a theme from `marchyo theme list` (dark|light = Jylhis pair)")
  .option("--apply", "Also persist to the CLI state file and rebuild")
  .option("--revert", "Undo: back to the declarative theme")
  .option("--rebuild", "Deprecated alias for --apply")
  .addHelpText(
    "after",
    `
Default is a live, ephemeral switch (resets on activation). --apply
additionally persists the selection and runs nixos-rebuild.

Examples:
  $ marchyo theme set nord
  $ marchyo theme set dark
  $ marchyo theme set gruvbox-dark-hard --apply
  $ marchyo theme set nord --revert
`,
  )
  .action(
    async (
      name: string,
      opts: { apply?: boolean; revert?: boolean; rebuild?: boolean },
    ) => {
      process.exit(await runThemeSet(rt(), name, opts));
    },
  );

theme
  .command("next")
  .description("Cycle to the next theme in the manifest")
  .option("--apply", "Also persist to the CLI state file and rebuild")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo theme next
`,
  )
  .action(async (opts: { apply?: boolean }) => {
    process.exit(await runThemeNext(rt(), opts));
  });

theme
  .command("transparency")
  .description("Show or set window transparency live (opaque|transparent|glassy)")
  .argument("[mode]", "opaque | transparent | glassy (omit to list)")
  .option("--revert", "Undo: back to the declarative transparency")
  .addHelpText(
    "after",
    `
Live and ephemeral; marchyo.theme.appearance.transparency is the
declarative default.

Examples:
  $ marchyo theme transparency glassy
  $ marchyo theme transparency --revert
`,
  )
  .action(async (mode: string | undefined, opts: { revert?: boolean }) => {
    process.exit(await runThemeTransparency(rt(), mode, opts));
  });

theme
  .command("corners")
  .description("Show or set window corners live (theme|sharp|rounded)")
  .argument("[mode]", "theme | sharp | rounded (omit to list)")
  .option("--revert", "Undo: back to the declarative corners")
  .addHelpText(
    "after",
    `
Live and ephemeral; marchyo.theme.appearance.corners is the declarative
default.

Examples:
  $ marchyo theme corners rounded
  $ marchyo theme corners --revert
`,
  )
  .action(async (mode: string | undefined, opts: { revert?: boolean }) => {
    process.exit(await runThemeCorners(rt(), mode, opts));
  });

theme
  .command("gaps")
  .description("Show or set window gaps (on|off); persist with --apply")
  .argument("[state]", "on | off (omit to show the modes)")
  .option("--apply", "Also persist marchyo.theme.appearance.gaps and rebuild")
  .option("--revert", "Undo: back to the declarative gaps")
  .addHelpText(
    "after",
    `
Live and ephemeral by default; marchyo.theme.appearance.gaps is the
declarative default. "marchyo toggle gaps" flips the same setting live.

Examples:
  $ marchyo theme gaps on
  $ marchyo theme gaps off --apply
  $ marchyo theme gaps --revert
`,
  )
  .action(
    async (
      state: string | undefined,
      opts: { apply?: boolean; revert?: boolean },
    ) => {
      process.exit(await runThemeGaps(rt(), state, opts));
    },
  );

theme
  .command("bar-position")
  .description("Show or set the shell bar position live (top|bottom)")
  .argument("[position]", "top | bottom (omit to list)")
  .option("--revert", "Undo: back to the declarative position")
  .addHelpText(
    "after",
    `
Live and ephemeral; written to the shell style file the shell watches.

Examples:
  $ marchyo theme bar-position bottom
  $ marchyo theme bar-position --revert
`,
  )
  .action(async (position: string | undefined, opts: { revert?: boolean }) => {
    process.exit(await runThemeBarPosition(rt(), position, opts));
  });

theme
  .command("bar-background")
  .description("Show or set the shell bar background live (opaque|glassy|clear)")
  .argument("[mode]", "opaque | glassy | clear (omit to list)")
  .option("--revert", "Undo: back to the declarative background")
  .addHelpText(
    "after",
    `
Live and ephemeral; written to the shell style file the shell watches.

Examples:
  $ marchyo theme bar-background glassy
  $ marchyo theme bar-background --revert
`,
  )
  .action(async (mode: string | undefined, opts: { revert?: boolean }) => {
    process.exit(await runThemeBarBackground(rt(), mode, opts));
  });

theme
  .command("icons")
  .description("List installed icon themes or set the icon theme live")
  .argument("[name]", "an icon theme directory name (omit to list)")
  .option("--revert", "Undo: back to the declarative icon theme")
  .addHelpText(
    "after",
    `
Live and ephemeral (dconf); the declarative default is gtk.iconTheme.

Examples:
  $ marchyo theme icons
  $ marchyo theme icons Papirus-Dark
  $ marchyo theme icons --revert
`,
  )
  .action(async (name: string | undefined, opts: { revert?: boolean }) => {
    process.exit(await runThemeIcons(rt(), name, opts));
  });

theme
  .command("generate")
  .description("Generate and apply a theme from a wallpaper image (matugen)")
  .argument("[image]", "path to a wallpaper image")
  .option("--light", "Force a light scheme (default: matugen decides)")
  .option("--dark", "Force a dark scheme (default: matugen decides)")
  .option("--revert", "Undo: back to the declarative theme")
  .addHelpText(
    "after",
    `
Runtime-only: recolors the shell, terminal, Hyprland borders, and wallpaper
live from the image's palette. Build-time surfaces (Qt, bat, fzf) keep the
declarative theme until the next rebuild. A rebuild resets everything.

Examples:
  $ marchyo theme generate ~/Pictures/wall.jpg
  $ marchyo theme generate ~/Pictures/wall.jpg --light
  $ marchyo theme generate --revert
`,
  )
  .action(
    async (
      image: string | undefined,
      opts: { light?: boolean; dark?: boolean; revert?: boolean },
    ) => {
      process.exit(await runThemeGenerate(rt(), image ?? "", opts));
    },
  );

const bg = program
  .command("bg")
  .description("Set or cycle the wallpaper (runtime-only)");

bg.command("set")
  .description("Set the wallpaper to an image file")
  .argument("[path]", "image file (omit with --revert)")
  .option("--revert", "Back to the active theme's wallpaper")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo bg set ~/Pictures/wall.png
  $ marchyo bg set --revert
`,
  )
  .action(async (path: string | undefined, opts: { revert?: boolean }) => {
    process.exit(await runBgSet(rt(), path ?? "", opts));
  });

bg.command("list")
  .description("List selectable wallpapers (theme, package and ~/Pictures/Wallpapers)")
  .addHelpText(
    "after",
    `
--format json prints [{ path, name, source: theme|package|user, current }].

Examples:
  $ marchyo bg list
  $ marchyo bg list --format json
`,
  )
  .action(async () => {
    process.exit(await runBgList(rt()));
  });

bg.command("next")
  .description("Cycle through the selectable wallpapers (see bg list)")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo bg next
`,
  )
  .action(async () => {
    process.exit(await runBgNext(rt()));
  });

program
  .command("rebuild")
  .description("Run nixos-rebuild switch against the detected flake")
  .option("-n, --dry-run", "Run dry-activate instead of switch")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo rebuild
  $ marchyo rebuild --dry-run
`,
  )
  .action(async (opts: { dryRun?: boolean }) => {
    process.exit(await runRebuild(rt(), { dryRun: opts.dryRun ?? false }));
  });

program
  .command("update")
  .description("Update flake inputs (nix flake update) in the detected flake")
  .option("-n, --dry-run", "Print the command instead of running it")
  .option("--check", "Only report whether the flake lock pins a newer nixpkgs than the running system")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo update
  $ marchyo update --dry-run
  $ marchyo update --check --json
`,
  )
  .action(async (opts: { dryRun?: boolean; check?: boolean }) => {
    process.exit(
      await runUpdate(rt(), { dryRun: opts.dryRun ?? false, check: opts.check ?? false }),
    );
  });

program
  .command("upgrade")
  .description("Update flake inputs, then nixos-rebuild switch")
  .option("-n, --dry-run", "Print the commands instead of running them")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo upgrade
  $ marchyo upgrade --dry-run
`,
  )
  .action(async (opts: { dryRun?: boolean }) => {
    process.exit(await runUpgrade(rt(), { dryRun: opts.dryRun ?? false }));
  });

program
  .command("rollback")
  .description("Switch back to the previous system generation")
  .option("-n, --dry-run", "Print the command instead of running it")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo rollback
  $ marchyo rollback --dry-run
`,
  )
  .action(async (opts: { dryRun?: boolean }) => {
    process.exit(await runRollback(rt(), { dryRun: opts.dryRun ?? false }));
  });

program
  .command("gc")
  .description("Collect Nix garbage (old generations and unreferenced paths)")
  .option(
    "--delete-older-than <period>",
    "delete generations older than <days>d",
    "14d",
  )
  .option("-n, --dry-run", "Print the command instead of running it")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo gc
  $ marchyo gc --delete-older-than 30d
  $ marchyo gc --dry-run
`,
  )
  .action(async (opts: { deleteOlderThan: string; dryRun?: boolean }) => {
    process.exit(
      await runGc(rt(), {
        olderThan: opts.deleteOlderThan,
        dryRun: opts.dryRun ?? false,
      }),
    );
  });

program
  .command("diff")
  .description("Show what changed between system generations (via dix)")
  .option("-n, --dry-run", "Print the command instead of running it")
  .addHelpText(
    "after",
    `
Compares /run/current-system against a newer pending generation when one
exists, otherwise the last two system generations.

Examples:
  $ marchyo diff
  $ marchyo diff --dry-run
`,
  )
  .action(async (opts: { dryRun?: boolean }) => {
    process.exit(await runDiff(rt(), { dryRun: opts.dryRun ?? false }));
  });

program
  .command("debug")
  .description("Print a diagnostics bundle (versions, generation, journal errors)")
  .addHelpText(
    "after",
    `
All probes are best-effort; unavailable data is reported as unknown/null.

Examples:
  $ marchyo debug
  $ marchyo debug --json
`,
  )
  .action(async () => {
    process.exit(await runDebug(rt()));
  });

program
  .command("doctor")
  .description("Check session health (baked tool paths, IPC sockets, shell plugins, user services)")
  .addHelpText(
    "after",
    `
Each check reports PASS, WARN, FAIL, or SKIP (not applicable on this host).
Exits 1 when any check fails; warnings do not change the exit code.

Examples:
  $ marchyo doctor
  $ marchyo doctor --json | jq '.checks[] | select(.status == "fail")'
`,
  )
  .action(async () => {
    process.exit(await runDoctor(rt()));
  });

const shellCmd = program
  .command("shell")
  .description("Drive the running marchyo shell (panels, launcher, overview, bar, notifications, lock)");

for (const action of ["toggle", "open"] as const) {
  shellCmd
    .command(action)
    .description(`${action === "toggle" ? "Toggle" : "Open"} a shell panel`)
    .argument("<panel>", "panel id: controlcenter | audio | network | power | monitor | notifications | …")
    .action(async (panel: string) => {
      process.exit(await runShellPanel(rt(), action, panel));
    });
}

shellCmd
  .command("close")
  .description("Close the open shell panel, or only the named one")
  .argument("[panel]", "panel id (omit to close whichever is open)")
  .action(async (panel: string | undefined) => {
    process.exit(await runShellPanel(rt(), "close", panel));
  });

shellCmd
  .command("gallery")
  .description("Open the Ui gallery panel (dev), optionally at one section")
  .argument("[section]", "states | buttons | inputs | choices | panel | popups | dialogs")
  .action(async (section: string | undefined) => {
    process.exit(await runShellGallery(rt(), section));
  });

shellCmd
  .command("launcher")
  .description("Toggle the launcher in a mode")
  .argument("<mode>", "apps | emoji | clipboard")
  .action(async (mode: string) => {
    process.exit(await runShellLauncher(rt(), mode));
  });

shellCmd
  .command("bar")
  .description("Toggle the top bar, or set it on/off")
  .argument("[state]", "on | off (omit to flip)")
  .action(async (state: string | undefined) => {
    process.exit(await runShellBar(rt(), state));
  });

shellCmd
  .command("overview")
  .description("Toggle the window overview, or open/close it")
  .argument("[state]", "on | off (omit to flip)")
  .action(async (state: string | undefined) => {
    process.exit(await runShellOverview(rt(), state));
  });

shellCmd
  .command("lock")
  .description("Lock the session with the shell lock screen")
  .action(async () => {
    process.exit(await runShellLock(rt()));
  });

shellCmd
  .command("lock-state")
  .description("Print the lock screen state: locked | unlocked")
  .action(async () => {
    process.exit(await runShellLockState(rt()));
  });

shellCmd
  .command("bar-state")
  .description("Print the top bar state: on | off")
  .action(async () => {
    process.exit(await runShellBarState(rt()));
  });

shellCmd
  .command("dnd-state")
  .description("Print the do-not-disturb state: on | off")
  .action(async () => {
    process.exit(await runShellDndState(rt()));
  });

shellCmd
  .command("dismiss")
  .description("Dismiss the newest notification toast")
  .option("--all", "Dismiss every notification toast")
  .action(async (opts: { all?: boolean }) => {
    process.exit(await runShellDismiss(rt(), opts.all === true));
  });

shellCmd
  .command("notify-keys")
  .description("Control the notification toasts from the keyboard")
  .action(async () => {
    process.exit(await runShellNotifyKeys(rt()));
  });

shellCmd
  .command("dnd")
  .description("Toggle do-not-disturb, or set it on/off")
  .argument("[state]", "on | off (omit to flip)")
  .action(async (state: string | undefined) => {
    process.exit(await runShellDnd(rt(), state));
  });

shellCmd
  .command("reload")
  .description("Reload the shell's QML in place")
  .action(async () => {
    process.exit(await runShellReload(rt()));
  });

shellCmd.addHelpText(
  "after",
  `
Exits 1 with a hint when marchyo-shell is not installed or not running.

Examples:
  $ marchyo shell toggle audio
  $ marchyo shell close notifications
  $ marchyo shell launcher emoji
  $ marchyo shell gallery buttons
  $ marchyo shell dnd on
  $ marchyo shell bar off
  $ marchyo shell bar-state
  $ marchyo shell overview
  $ marchyo shell reload
`,
);

program
  .command("volume")
  .description("Step or mute the default audio sink (or source with --mic)")
  .argument("<action>", "up | down | mute")
  .option("--mic", "Act on the default source (microphone)")
  .addHelpText(
    "after",
    `
With the marchyo shell installed: wpctl (the shell OSD follows Pipewire).
Without it: swayosd-client when installed, else wpctl. wpctl steps 5% and
caps at 100%.

Examples:
  $ marchyo volume up
  $ marchyo volume mute --mic
`,
  )
  .action(async (action: string, opts: { mic?: boolean }) => {
    process.exit(await runVolume(rt(), action, opts));
  });

program
  .command("brightness")
  .description("Step the backlight brightness")
  .argument("<action>", "up | down (toggle with --keyboard)")
  .option("--keyboard", "Act on the keyboard backlight (up | down | toggle)")
  .addHelpText(
    "after",
    `
With the marchyo shell installed: brightnessctl, then an OSD poke over
shell IPC. Without it: swayosd-client when installed, else brightnessctl.
brightnessctl steps 5%. --keyboard steps the *kbd_backlight* LED by 10%.

Examples:
  $ marchyo brightness up
  $ marchyo brightness --keyboard toggle
`,
  )
  .action(async (action: string, opts: { keyboard?: boolean }) => {
    process.exit(await runBrightness(rt(), action, opts));
  });

program
  .command("toggle")
  .description("Flip a desktop toggle live (gaps, nightlight, waybar, …)")
  .argument(
    "<name>",
    "gaps | transparency | animations | reduce-motion | fullscreen-desktop | nightlight | waybar | touchpad | touchscreen | idle | screensaver | notifications | suspend | caffeine | hybrid-gpu",
  )
  .argument("[state]", "on | off (omit to flip)")
  .option(
    "--apply",
    "Also persist declaratively and rebuild (hybrid-gpu, reduce-motion)",
  )
  .option("--revert", "Undo: back to the declarative default")
  .option("--status", "Print the current state instead of toggling")
  .addHelpText(
    "after",
    `
Toggles are live, and "marchyo runtime restore" replays them. hybrid-gpu
is --apply-only; reduce-motion also takes --apply. --status is scriptable
(used by the waybar indicator).

Examples:
  $ marchyo toggle nightlight
  $ marchyo toggle notifications off
  $ marchyo toggle waybar --status
  $ marchyo toggle hybrid-gpu on --apply
`,
  )
  .action(
    async (
      name: string,
      state: string | undefined,
      opts: { apply?: boolean; revert?: boolean; status?: boolean },
    ) => {
      process.exit(await runToggle(rt(), name, state, opts));
    },
  );

const capture = program
  .command("capture")
  .description("Screenshots, screen recording, OCR, and color picking");

capture
  .command("screenshot")
  .description("Take a screenshot (grimblast)")
  .option("--target <t>", "area | active | output | screen", "area")
  .option("--edit", "Annotate in satty before saving")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo capture screenshot
  $ marchyo capture screenshot --target output
  $ marchyo capture screenshot --edit
`,
  )
  .action(async (opts: { target?: string; edit?: boolean }) => {
    process.exit(await runCaptureScreenshot(rt(), opts));
  });

capture
  .command("record")
  .description("Toggle region screen recording (gpu-screen-recorder)")
  .option("--audio <src>", "none | desktop | mic", "none")
  .addHelpText(
    "after",
    `
First invocation selects a region and starts recording; the next stops
and finalizes the mp4 in ~/Videos/Recordings.

Examples:
  $ marchyo capture record
  $ marchyo capture record --audio desktop
`,
  )
  .action(async (opts: { audio?: string }) => {
    process.exit(await runCaptureRecord(rt(), opts));
  });

capture
  .command("ocr")
  .description("Select a region, OCR it, copy the text to the clipboard")
  .action(async () => {
    process.exit(await runCaptureOcr(rt()));
  });

capture
  .command("color")
  .description("Pick a color from the screen (hex to clipboard)")
  .action(async () => {
    process.exit(await runCaptureColor(rt()));
  });

program
  .command("window")
  .description("Window utilities: pop out, close all, tiled fullscreen")
  .argument("<action>", "pop | close-all | tiled-fullscreen")
  .addHelpText(
    "after",
    `
pop floats, centres and pins the focused tile (and puts it back). Gaps
and the fullscreen desktop are toggles: marchyo toggle gaps|fullscreen-desktop.

Examples:
  $ marchyo window pop
  $ marchyo window close-all
`,
  )
  .action(async (action: string) => {
    process.exit(await runWindow(rt(), action));
  });

const menu = program
  .command("menu")
  .description("Open the command menu in the marchyo shell (gum TUI fallback)")
  .argument("[route]", "dotted menu id: capture, appearance.theme, system, power (default: root)")
  .option("--tui", "use the gum terminal menu instead of the shell")
  .addHelpText(
    "after",
    `
The shell opens the menu when it is running; an unknown route opens the root.
Without the shell, or with --tui, power and system open the power menu,
appearance the appearance menu, and anything else the main menu.

Examples:
  $ marchyo menu
  $ marchyo menu capture
  $ marchyo menu appearance.theme
  $ marchyo menu power --tui
`,
  )
  .action(async (route: string | undefined, opts: { tui?: boolean }) => {
    process.exit(await runMenu(rt(), route, opts));
  });

menu
  .command("select")
  .description("dmenu-style picker: rows on stdin, the choice on stdout")
  .option("--prompt <text>", "prompt text")
  .option("--multiple", "allow several choices; prints a JSON array")
  .option("--selected <value...>", "values that start selected")
  .option("--width <px>", "menu width in pixels")
  .option("--maxheight <px>", "maximum list height in pixels")
  .option("--on-change <json>", "JSON argv array to run when the highlighted row changes")
  .option("--change-key <key>", "key that triggers --on-change")
  .option("--tui", "fall back to gum when the shell is not reachable")
  .addHelpText(
    "after",
    `
Rows are TAB separated: label, glyph label, label subtext, or glyph label
subtext. With two fields the first is a glyph when it has at most two
characters. A chosen row prints its label, or label TAB subtext. Exit 1 on
cancel, 2 when the shell is not reachable.
`,
  )
  .action(async (_opts, cmd: Command) => {
    process.exit(await runMenuSelect(rt(), cmd.optsWithGlobals()));
  });

menu
  .command("input")
  .description("Prompt for a line of text in the shell and print it")
  .option("--prompt <text>", "prompt text")
  .option("--width <px>", "menu width in pixels")
  .option("--tui", "fall back to gum when the shell is not reachable")
  .addHelpText(
    "after",
    `
Exit 1 on cancel, 2 when the shell is not reachable.
`,
  )
  .action(async (_opts, cmd: Command) => {
    process.exit(await runMenuInput(rt(), cmd.optsWithGlobals()));
  });

program
  .command("keybindings")
  .description("Searchable Hyprland keybinding cheat sheet (fzf)")
  .action(async () => {
    process.exit(await runKeybindings(rt()));
  });

program
  .command("launch")
  .description("Launch an app detached (file-manager opens at the focused cwd)")
  .argument("<app>", "command name, or file-manager | browser | terminal | floating-terminal")
  .argument("[args...]", "arguments passed through")
  .action(async (app: string, args: string[]) => {
    process.exit(await runLaunch(rt(), app, args));
  });

program
  .command("focus-or-launch")
  .description("Focus a window by class, or launch the command")
  .argument("<class>", "window class to match")
  .argument("[command...]", "command to launch when absent (default: the class name)")
  .action(async (className: string, command: string[]) => {
    process.exit(await runFocusOrLaunch(rt(), className, command));
  });

program
  .command("zoom")
  .description("Step the cursor zoom factor")
  .argument("<direction>", "in | out | reset")
  .action(async (direction: string) => {
    process.exit(await runZoom(rt(), direction));
  });

const monitor = program
  .command("monitor")
  .description("Monitor helpers (scale cycling, laptop panel)");

monitor
  .command("scale-cycle")
  .description("Cycle the focused monitor's scale (1 → 1.25 → … → 2 → 1)")
  .action(async () => {
    process.exit(await runMonitorScaleCycle(rt()));
  });

monitor
  .command("laptop-toggle")
  .description("Toggle the built-in laptop panel (eDP*) on/off")
  .action(async () => {
    process.exit(await runMonitorLaptopToggle(rt()));
  });

monitor
  .command("clamshell")
  .description("Lid switch handler: hide the laptop panel while an external display is on")
  .argument("<state>", "on (lid closed) | off (lid open)")
  .action(async (state: string) => {
    process.exit(await runMonitorClamshell(rt(), state));
  });

monitor
  .command("reset")
  .description("Forget the display panel's saved settings")
  .action(async () => {
    process.exit(await runMonitorReset(rt()));
  });

monitor
  .command("save")
  .description("Print the current display layout")
  .option("--nix", "as a marchyo.monitors snippet")
  .action(async (opts: { nix?: boolean }) => {
    process.exit(await runMonitorSave(rt(), opts));
  });

const monitorWorkspaces = monitor
  .command("workspaces")
  .description("Per-monitor workspace blocks (marchyo.workspaces.perMonitor)");

monitorWorkspaces
  .command("reset")
  .description("Forget which workspace block each monitor owns")
  .action(async () => {
    process.exit(await runMonitorWorkspacesReset(rt()));
  });

program
  .command("lock")
  .description("Lock the screen (shell or hyprlock)")
  .action(async () => {
    process.exit(await runLock(rt()));
  });

program
  .command("logout")
  .description("End the session cleanly (uwsm → hyprctl exit → loginctl)")
  .action(async () => {
    process.exit(await runLogout(rt()));
  });

program
  .command("suspend")
  .description("Suspend the system")
  .action(async () => {
    process.exit(await runSuspend(rt()));
  });

program
  .command("hibernate")
  .description("Hibernate the system")
  .action(async () => {
    process.exit(await runHibernate(rt()));
  });

program
  .command("reboot")
  .description("Reboot the system")
  .option("--firmware", "reboot into the UEFI firmware setup")
  .action(async (opts: { firmware?: boolean }) => {
    process.exit(await (opts.firmware ? runRebootFirmware(rt()) : runReboot(rt())));
  });

program
  .command("shutdown")
  .description("Power the system off")
  .action(async () => {
    process.exit(await runShutdown(rt()));
  });

program
  .command("powerprofile")
  .description("Get, list, or set the power profile")
  .argument("<action>", "get | list | set")
  .argument("[profile]", "power-saver | balanced | performance (for set)")
  .action(async (action: string, profile: string | undefined) => {
    process.exit(await runPowerprofile(rt(), action, profile));
  });

const reminder = program
  .command("reminder")
  .description("Reminders via transient systemd user timers");

reminder
  .command("set")
  .description("Schedule a reminder (prompts via gum when args are omitted)")
  .argument("[message]", "reminder text")
  .argument("[delay]", "systemd time span: 10m, 2h, 1h30m…")
  .action(async (message: string | undefined, delay: string | undefined) => {
    process.exit(await runReminderSet(rt(), message, delay));
  });

reminder
  .command("show")
  .description("Show pending reminder timers and the reminder log")
  .action(async () => {
    process.exit(await runReminderShow(rt()));
  });

reminder
  .command("clear")
  .description("Cancel pending reminders and clear the log")
  .action(async () => {
    process.exit(await runReminderClear(rt()));
  });

program
  .command("info")
  .description("Quick-info notification (datetime, battery)")
  .argument("<what>", "datetime | battery")
  .action(async (what: string) => {
    process.exit(await runInfo(rt(), what));
  });

program
  .command("transcode")
  .description("Transcode media next to the source (ffmpeg / tte / chafa)")
  .argument("[file]", "source file (gum picker when omitted)")
  .option("--to <fmt>", "mp4 | webm | gif (gum prompt when omitted)")
  .option("--ascii", "Animate the file's text with tte instead")
  .option("--image-ascii", "Render an image as ASCII/ANSI art with chafa")
  .action(
    async (
      file: string | undefined,
      opts: { to?: string; ascii?: boolean; imageAscii?: boolean },
    ) => {
      process.exit(await runTranscode(rt(), file, opts));
    },
  )
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo transcode video.mov --to mp4
  $ marchyo transcode notes.txt --ascii
  $ marchyo transcode photo.jpg --image-ascii
`,
  );

program
  .command("share")
  .description("Send files, folders or clipboard text to a LocalSend device")
  .argument("[paths...]", "files or folders to send (gum menu when omitted)")
  .option("--to <alias|ip>", "Send to this device (alias, IPv4 or IPv4:port)")
  .option("--pin <pin>", "PIN the receiving device asks for")
  .option("--clipboard", "Copy the file's contents (or a folder's path) instead")
  .option("--tailscale <peer>", "Send over Taildrop to this tailnet machine")
  .option("--tailscale-receive", "Save incoming Taildrop files (to [paths], default ~/Downloads)")
  .action(
    async (
      paths: string[],
      opts: {
        to?: string;
        pin?: string;
        clipboard?: boolean;
        tailscale?: string;
        tailscaleReceive?: boolean;
      },
    ) => {
      process.exit(await runShare(rt(), paths, opts));
    },
  )
  .addHelpText(
    "after",
    `
Discovers LocalSend devices on the local network for about 2 s. One device
is used directly; several open a picker (or need --to under --no-input).

Examples:
  $ marchyo share photo.jpg
  $ marchyo share ~/Documents/trip --to Pixel
  $ marchyo share report.pdf --to 192.168.1.20 --json
  $ marchyo share notes.txt --clipboard
  $ marchyo share photo.jpg --tailscale laptop
  $ marchyo share --tailscale-receive
`,
  );

const font = program
  .command("font")
  .description("Terminal and UI fonts: list, current, or runtime switch");

font
  .command("list")
  .description("List installed font families (monospace by default)")
  .option("--kind <kind>", "mono | ui | all", "mono")
  .action(async (opts: { kind: FontKind }) => {
    process.exit(await runFontList(rt(), opts.kind));
  });

font
  .command("current")
  .description("Show the active terminal font")
  .action(async () => {
    process.exit(await runFontCurrent(rt()));
  });

font
  .command("set")
  .description("Switch the terminal or UI font live")
  .argument("[family]", "font family name (omit with --revert)")
  .option("--kind <kind>", "mono (ghostty) | ui (GTK and shell) | all", "mono")
  .option("--revert", "Back to the declarative font")
  .action(
    async (family: string | undefined, opts: { revert?: boolean; kind: FontKind }) => {
      process.exit(await runFontSet(rt(), family, opts));
    },
  );

const bar = program
  .command("bar")
  .description("Edit the shell bar live: widgets, sections, position, background")
  .addHelpText(
    "after",
    `
Edits are recorded in $XDG_STATE_HOME/marchyo/shell/bar-layout.json and applied
by the shell over the layout from marchyo.shell.settings; "marchyo bar reset"
returns to that layout. Sections: left, centerBegin, center, centerEnd, right.
Widget ids are listed in the shell configuration reference.
`,
  );

bar
  .command("list")
  .description("Show the recorded bar layout edits")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo bar list
  $ marchyo bar list --format json
`,
  )
  .action(async () => {
    process.exit(await runBarList(rt()));
  });

bar
  .command("put")
  .description("Move or add a widget in a bar section")
  .argument("<id>", "widget id, for example marchyo.cpu")
  .argument("<section>", "left | centerBegin | center | centerEnd | right")
  .option("--at <index>", "position in the section (default: the end)")
  .addHelpText(
    "after",
    `
A widget already on the bar moves and keeps its settings; a separator
(marchyo.separator) is added instead of moved.

Examples:
  $ marchyo bar put marchyo.cpu left
  $ marchyo bar put marchyo.dnd centerEnd --at 0
`,
  )
  .action(async (id: string, section: string, opts: { at?: string }) => {
    process.exit(await runBarPut(rt(), id, section, opts));
  });

bar
  .command("move")
  .description("Shift a widget along its section")
  .argument("<id>", "widget id")
  .argument("<direction>", "left (towards the start) | right")
  .argument("[count]", "places to move (default 1)")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo bar move marchyo.cpu left
  $ marchyo bar move marchyo.battery right 2
`,
  )
  .action(async (id: string, direction: string, count: string | undefined) => {
    process.exit(await runBarMove(rt(), id, direction, count));
  });

bar
  .command("remove")
  .description("Take a widget off the bar")
  .argument("<id>", "widget id")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo bar remove marchyo.media
`,
  )
  .action(async (id: string) => {
    process.exit(await runBarRemove(rt(), id));
  });

bar
  .command("set")
  .description("Replace a bar section with the listed widgets")
  .argument("<section>", "left | centerBegin | center | centerEnd | right")
  .argument("[ids...]", "widget ids in order (none empties the section)")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo bar set center marchyo.clock
  $ marchyo bar set centerEnd marchyo.dnd marchyo.caffeine
  $ marchyo bar set centerBegin
`,
  )
  .action(async (section: string, ids: string[]) => {
    process.exit(await runBarSet(rt(), section, ids));
  });

bar
  .command("reset")
  .description("Drop every recorded bar layout edit")
  .addHelpText(
    "after",
    `
Examples:
  $ marchyo bar reset
`,
  )
  .action(async () => {
    process.exit(await runBarReset(rt()));
  });

bar
  .command("background")
  .description("Show or set the bar background (opaque|glassy|clear)")
  .argument("[mode]", "opaque | glassy | clear (omit to list)")
  .option("--revert", "Undo: back to the declarative background")
  .addHelpText(
    "after",
    `
Same as "marchyo theme bar-background". Double-clicking empty bar space
steps through the modes.

Examples:
  $ marchyo bar background glassy
  $ marchyo bar background --revert
`,
  )
  .action(async (mode: string | undefined, opts: { revert?: boolean }) => {
    process.exit(await runBarBackground(rt(), mode, opts));
  });

bar
  .command("position")
  .description("Show or set the bar position (top|bottom)")
  .argument("[position]", "top | bottom (omit to list)")
  .option("--revert", "Undo: back to the declarative position")
  .addHelpText(
    "after",
    `
Same as "marchyo theme bar-position".

Examples:
  $ marchyo bar position bottom
  $ marchyo bar position --revert
`,
  )
  .action(async (position: string | undefined, opts: { revert?: boolean }) => {
    process.exit(await runBarPosition(rt(), position, opts));
  });

program
  .command("dictation")
  .description("Start, stop or toggle voice dictation on the configured backend")
  .argument("<action>", "start | stop | toggle | status")
  .addHelpText(
    "after",
    `
The backend (Superwhisper, Voxtype or Hex) comes from marchyo.dictation.backend.
Concurrent calls are serialised; status prints idle, recording, transcribing or
stopped (--json adds the backend name).

Examples:
  $ marchyo dictation toggle
  $ marchyo dictation status --json
`,
  )
  .action(async (action: string) => {
    process.exit(await runDictation(rt(), action));
  });

program
  .command("language")
  .description("Show or set marchyo's display language (shell and CLI strings)")
  .argument("[code]", "language code, or 'list' (omit to show the current one)")
  .option("--revert", "Drop the runtime override, back to marchyo.language")
  .action(async (code: string | undefined, opts: { revert?: boolean }) => {
    process.exit(await runLanguage(rt(), code, opts));
  });

program
  .command("install")
  .description("Enable a marchyo feature declaratively (state + rebuild)")
  .argument("<feature>", "desktop | development | media | office | dictation | webapps")
  .option("-n, --dry-run", "Print the state change without writing or rebuilding")
  .action(async (feature: string, opts: { dryRun?: boolean }) => {
    process.exit(await runInstall(rt(), feature, opts));
  });

program
  .command("remove")
  .description("Disable a marchyo feature declaratively (state + rebuild)")
  .argument("<feature>", "desktop | development | media | office | dictation | webapps")
  .option("-n, --dry-run", "Print the state change without writing or rebuilding")
  .action(async (feature: string, opts: { dryRun?: boolean }) => {
    process.exit(await runRemove(rt(), feature, opts));
  });

const network = program
  .command("network")
  .description("Network helpers (captive-portal sign-in)");

network
  .command("portal")
  .description("Open the captive-portal sign-in window and wait until online")
  .option("--uri <url>", "Page to open (default: marchyo.network.connectivityCheck.uri)")
  .option("--browser <cmd>", "Chromium-family browser (default: the webapps browser)")
  .addHelpText(
    "after",
    `
Pauses an active Tailscale exit node, opens the check URI in a browser app
window, polls NetworkManager every 2s (every 15s after 5 minutes) until
connectivity is full, then closes the window and restores the exit node.

Examples:
  $ marchyo network portal
`,
  )
  .action(async (opts: { uri?: string; browser?: string }) => {
    process.exit(await runNetworkPortal(rt(), opts));
  });

const webapp = program
  .command("webapp")
  .description("Manage CLI-added web apps (PWA windows)");

webapp
  .command("add")
  .description("Register a site as a standalone app window")
  .argument("<url>", "site URL")
  .option("--name <name>", "display name (default: derived from the host)")
  .option("--key <key>", "SUPER+SHIFT launch key (checked against taken keys)")
  .option("--modifiers <mods>", "modifier chord (default: SUPER SHIFT)")
  .option("-n, --dry-run", "Print the state change without writing or rebuilding")
  .action(
    async (
      url: string,
      opts: { name?: string; key?: string; modifiers?: string; dryRun?: boolean },
    ) => {
      process.exit(await runWebappAdd(rt(), url, opts));
    },
  );

webapp
  .command("rm")
  .description("Remove a CLI-added web app")
  .argument("<name>", "app name (as shown in launchers)")
  .option("-n, --dry-run", "Print the state change without writing or rebuilding")
  .action(async (name: string, opts: { dryRun?: boolean }) => {
    process.exit(await runWebappRm(rt(), name, opts));
  });

const plugin = program
  .command("plugin")
  .description("Manage CLI-added shell plugins (build-time, baked on rebuild)");

plugin
  .command("add")
  .description("Pin a shell plugin from a git URL and bake it in on rebuild")
  .argument("<url>", "git URL of the plugin repository")
  .option("--rev <rev>", "git revision to pin (default: the remote HEAD)")
  .option("-n, --dry-run", "Print the state change without writing or rebuilding")
  .action(async (url: string, opts: { rev?: string; dryRun?: boolean }) => {
    process.exit(await runPluginAdd(rt(), url, opts));
  });

plugin
  .command("list")
  .description("List the plugins baked into the installed shell, plus CLI-added ones pending a rebuild")
  .action(async () => {
    process.exit(await runPluginList(rt()));
  });

plugin
  .command("update")
  .description("Re-pin CLI-added shell plugins at their source and rebuild when any changed")
  .argument("[id]", "plugin manifest id (default: every CLI-added plugin)")
  .option("--rev <rev>", "git revision to pin (needs an id; default: the remote HEAD)")
  .option("-n, --dry-run", "Print the state change without writing or rebuilding")
  .action(async (id: string | undefined, opts: { rev?: string; dryRun?: boolean }) => {
    process.exit(await runPluginUpdate(rt(), id, opts));
  });

plugin
  .command("remove")
  .description("Remove a CLI-added shell plugin")
  .argument("<id>", "plugin manifest id")
  .option("-n, --dry-run", "Print the state change without writing or rebuilding")
  .action(async (id: string, opts: { dryRun?: boolean }) => {
    process.exit(await runPluginRemove(rt(), id, opts));
  });

plugin
  .command("validate")
  .description("Check a plugin checkout against the manifest rules the build enforces")
  .argument("<dir>", "plugin directory (holds manifest.json)")
  .action(async (dir: string) => {
    process.exit(await runPluginValidate(rt(), dir));
  });

const security = program
  .command("security")
  .description("Security enrollment helpers");

security
  .command("enroll")
  .description("Enroll a FIDO2 key or a fingerprint")
  .argument("<method>", "fido2 | fingerprint")
  .action(async (method: string) => {
    process.exit(await runSecurityEnroll(rt(), method));
  });

const runtime = program
  .command("runtime")
  .description("Inspect or re-apply ephemeral runtime overrides");

runtime
  .command("status")
  .description("List active runtime overrides")
  .addHelpText(
    "after",
    `
Overrides are live changes made by mutating marchyo commands without
--apply. They reset on nixos-rebuild activation.

Examples:
  $ marchyo runtime status
  $ marchyo runtime status --format json
`,
  )
  .action(async () => {
    process.exit(await runRuntimeStatus(rt()));
  });

runtime
  .command("restore")
  .description("Re-apply stored runtime overrides (used at session start)")
  .addHelpText(
    "after",
    `
Restores the saved theme or Nix default, then the remaining overrides.
Failures are reported and return a nonzero status; independent overrides
still run. Runs at session start and after Home Manager activation.

Examples:
  $ marchyo runtime restore
`,
  )
  .action(async () => {
    process.exit(await runRuntimeRestore(rt()));
  });

program
  .command("completion")
  .description("Emit shell completions or the man page (generated from the live command tree)")
  .argument("<target>", "bash | zsh | fish | man")
  .action(async (target: string) => {
    process.exit(await runCompletion(rt(), program, target, VERSION));
  });

program
  .command("notify")
  .description("Send a desktop notification, optionally with click actions")
  .usage("[options] <headline> [description] [--exec <program> [args...] | --action <label> <program> [words...]... [--with <args...>]]")
  .argument("[args...]", "headline, description and flags (read untouched, not by commander)")
  .allowUnknownOption()
  .allowExcessArguments()
  .addHelpText(
    "after",
    `
Flags (before the headline, or after the description):
  --app-name <app>           sender name (default marchyo-action)
  -g, --glyph <glyph>        icon glyph shown on the card
  -u, --urgency <level>      low (default) | normal | critical
  -i, --icon <icon>          icon name
  -t, --expire-time <ms>     lifetime in milliseconds
  -r, --replace-id <id>      replace an earlier notification
  -p, --print-id             print the id of the new notification
  --transient                keep the card out of history
  --image <path-or-uri>      image shown on the card
  --exec <program> [args...] run on click; takes the rest of the line
  --action <label> <program> [words...]
                             a button (up to 3); the first also runs on click
  --with <args...>           arguments appended to every action

Each flag also takes the --flag=value form. The click command needs
$XDG_RUNTIME_DIR: the shell runs it only when the notification carries a
one-time token the command wrote there. A glyph needs the token too.
`,
  )
  .action(async (_args: string[], _opts: unknown, cmd: Command) => {
    process.exit(await runNotify(rt(), cmd.args));
  });

program
  .command("whats-new")
  .description("Show what the Marchyo NEWS gained since you last looked")
  .option("--notify", "send one notification when NEWS changed (used by a user unit at login)")
  .option("--mark-seen", "record the current NEWS as seen")
  .addHelpText(
    "after",
    `
--json prints { changed, hash, entries, summary }; summary is the dix
comparison of the last two system generations (at most 40 lines).

Examples:
  $ marchyo whats-new
  $ marchyo whats-new --json
  $ marchyo whats-new --mark-seen
`,
  )
  .action(async (opts: { notify?: boolean; markSeen?: boolean }) => {
    process.exit(await runWhatsNew(rt(), opts));
  });

const setup = program
  .command("setup")
  .description("First-login checklist: git, SSH, security keys, language, theme, dictation")
  .option("--done", "mark the checklist finished (hides the welcome)")
  .option("--welcome", "send the one-time welcome notification (used by a user unit at login)")
  .addHelpText(
    "after",
    `
Each item is done, todo or skip (not applicable here). --json prints
{ items: [{ id, title, status, detail, fix }], doneFlag }.

Examples:
  $ marchyo setup
  $ marchyo setup --json
  $ marchyo setup fix git
`,
  )
  .action(async (opts: { done?: boolean; welcome?: boolean }) => {
    process.exit(await runSetup(rt(), opts));
  });

setup
  .command("fix")
  .description("Run the interactive fix for one checklist item")
  .argument("<id>", "git | ssh | fido2 | fingerprint | language | keyboard | theme | dictation")
  .action(async (id: string) => {
    process.exit(await runSetupFix(rt(), id));
  });

attachExamples(program);
// `notify` reads its own flags and would lose them to commander; hand them
// over untouched, after any global options. Only a lone --help is left to
// commander.
const notifyArgv = splitNotifyArgv(process.argv.slice(2));
if (notifyArgv !== null && !(notifyArgv.rest.length === 1 && notifyArgv.rest[0] === "--help")) {
  program.parseOptions(notifyArgv.globals);
  process.exit(await runNotify(rt(), notifyArgv.rest));
}
await program.parseAsync(process.argv);

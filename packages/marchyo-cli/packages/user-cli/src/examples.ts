import type { Command } from "commander";

// Examples for leaf commands that carry no inline addHelpText. The contract
// lint (tests/command-lint.test.ts) fails a leaf command without examples.
const EXAMPLES: Record<string, string[]> = {
  "shell toggle": [
    "marchyo shell toggle audio",
    "marchyo shell toggle controlcenter",
    "marchyo shell toggle themes",
    "marchyo shell toggle backgrounds",
  ],
  "shell open": ["marchyo shell open network"],
  "shell close": ["marchyo shell close", "marchyo shell close audio"],
  "shell launcher": ["marchyo shell launcher apps", "marchyo shell launcher emoji"],
  "shell bar": ["marchyo shell bar", "marchyo shell bar off"],
  "shell overview": ["marchyo shell overview", "marchyo shell overview on"],
  "shell lock": ["marchyo shell lock"],
  "shell lock-state": ["marchyo shell lock-state"],
  "shell bar-state": ["marchyo shell bar-state"],
  "shell dnd-state": ["marchyo shell dnd-state"],
  "shell dismiss": ["marchyo shell dismiss", "marchyo shell dismiss --all"],
  "shell notify-keys": ["marchyo shell notify-keys"],
  "shell dnd": ["marchyo shell dnd", "marchyo shell dnd on"],
  "shell reload": ["marchyo shell reload"],
  "shell gallery": ["marchyo shell gallery", "marchyo shell gallery buttons"],
  "capture ocr": ["marchyo capture ocr"],
  "capture color": ["marchyo capture color"],
  "menu select": [
    "printf 'Lock\\nSuspend\\n' | marchyo menu select --prompt Power",
    "printf 'Dark\\nLight\\n' | marchyo menu select --multiple --selected Dark",
  ],
  "menu input": ["marchyo menu input --prompt Name"],
  keybindings: ["marchyo keybindings"],
  launch: ["marchyo launch firefox", "marchyo launch file-manager"],
  "focus-or-launch": ["marchyo focus-or-launch firefox", "marchyo focus-or-launch Slack slack"],
  zoom: ["marchyo zoom in", "marchyo zoom reset"],
  "monitor scale-cycle": ["marchyo monitor scale-cycle"],
  "monitor laptop-toggle": ["marchyo monitor laptop-toggle"],
  "monitor clamshell": ["marchyo monitor clamshell on", "marchyo monitor clamshell off"],
  "monitor reset": ["marchyo monitor reset"],
  "monitor save": ["marchyo monitor save", "marchyo monitor save --nix"],
  "monitor workspaces reset": ["marchyo monitor workspaces reset"],
  lock: ["marchyo lock"],
  logout: ["marchyo logout"],
  suspend: ["marchyo suspend"],
  hibernate: ["marchyo hibernate"],
  reboot: ["marchyo reboot", "marchyo reboot --firmware"],
  shutdown: ["marchyo shutdown"],
  powerprofile: ["marchyo powerprofile get", "marchyo powerprofile set balanced"],
  "reminder set": ["marchyo reminder set 'stand up' 30m", "marchyo reminder set"],
  "reminder show": ["marchyo reminder show"],
  "reminder clear": ["marchyo reminder clear"],
  info: ["marchyo info datetime", "marchyo info battery"],
  "font list": ["marchyo font list", "marchyo font list --kind ui --format json"],
  "font current": ["marchyo font current"],
  "font set": [
    "marchyo font set 'BlexMono Nerd Font'",
    "marchyo font set Inter --kind ui",
    "marchyo font set --kind all --revert",
  ],
  language: ["marchyo language", "marchyo language list", "marchyo language de"],
  install: ["marchyo install development --dry-run", "marchyo install media"],
  remove: ["marchyo remove media --dry-run"],
  "webapp add": ["marchyo webapp add https://app.example.com --name Example"],
  "webapp rm": ["marchyo webapp rm Example"],
  "plugin add": ["marchyo plugin add https://github.com/example/plugin --rev main"],
  "plugin list": ["marchyo plugin list"],
  "plugin update": ["marchyo plugin update", "marchyo plugin update my-plugin"],
  "plugin remove": ["marchyo plugin remove my-plugin"],
  "plugin validate": ["marchyo plugin validate ~/src/my-plugin"],
  "security enroll": ["marchyo security enroll fido2", "marchyo security enroll fingerprint"],
  "agent account list": ["marchyo agent account list", "marchyo agent account list claude"],
  "agent account use": ["marchyo agent account use claude work"],
  "agent account remove": ["marchyo agent account remove claude work"],
  "agent account rename": ["marchyo agent account rename claude work Work account"],
  "agent account import": [
    "marchyo agent account import",
    "marchyo agent account import --replace",
  ],
  notify: [
    "marchyo notify 'Build done' '3 tests failed' -u critical",
    "marchyo notify Reminder 'Stand up' --action 'Snooze' marchyo reminder set 'stand up' 10m",
    "marchyo notify -p Audio 'Open the panel' --exec marchyo shell open audio",
  ],
  "setup fix": ["marchyo setup fix git", "marchyo setup fix ssh"],
  completion: ["marchyo completion bash", "marchyo completion man"],
};

export function attachExamples(cmd: Command, path: string[] = []): void {
  for (const sub of cmd.commands as Command[]) {
    const key = [...path, sub.name()].join(" ");
    const lines = EXAMPLES[key];
    if (lines !== undefined && sub.commands.length === 0) {
      sub.addHelpText("after", `\nExamples:\n${lines.map((l) => `  $ ${l}`).join("\n")}\n`);
    }
    attachExamples(sub, [...path, sub.name()]);
  }
}

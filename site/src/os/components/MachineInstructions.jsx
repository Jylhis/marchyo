import { useState } from "react";
import { ChevronDown, ChevronUp, Terminal } from "lucide-react";

const STEPS = [
  {
    title: "Install marchyo in your flake",
    code: `# flake.nix
inputs.marchyo.url = "github:Jylhis/marchyo";
outputs = { marchyo, ... }: {
  nixosConfigurations.thinkpad-x1 = marchyo.lib.mkSystem {
    hostname = "thinkpad-x1";
    # ...
  };
};`,
  },
  {
    title: "Configure & build",
    code: `# Apply the configuration
sudo nixos-rebuild switch --flake .#thinkpad-x1`,
  },
  {
    title: "Register machine here",
    code: `# Click "Add machine" above, enter your hostname
# and assign it a config profile and git repo.`,
  },
];

export default function MachineInstructions({ collapsed = false }) {
  const [open, setOpen] = useState(!collapsed);

  return (
    <div className="border border-border mx-6 my-4">
      <button
        onClick={() => setOpen((o) => !o)}
        className="w-full flex items-center justify-between px-4 py-3 text-xs font-mono text-muted-foreground hover:text-foreground transition-colors bg-muted/30"
      >
        <span className="flex items-center gap-2">
          <Terminal className="w-3.5 h-3.5" />
          how to add a new machine
        </span>
        {open ? (
          <ChevronUp className="w-3.5 h-3.5" />
        ) : (
          <ChevronDown className="w-3.5 h-3.5" />
        )}
      </button>
      {open && (
        <div className="divide-y divide-border">
          {STEPS.map(({ title, code }) => (
            <div key={title} className="flex gap-4 p-4">
              <span className="font-mono text-xs text-decorator shrink-0 mt-0.5">
                ›
              </span>
              <div className="min-w-0 flex-1">
                <p className="text-xs font-medium text-foreground mb-2">
                  {title}
                </p>
                <pre className="terminal-block text-xs px-3 py-2 overflow-x-auto whitespace-pre">
                  {code}
                </pre>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

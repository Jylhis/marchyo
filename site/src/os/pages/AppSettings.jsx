import { useState } from "react";
import { User, Key, Cpu, Copy, Check } from "lucide-react";
import PageHeader from "@/components/PageHeader";

const EXAMPLE_USER = {
  email: "admin@example.com",
  full_name: "Example Admin",
  role: "admin",
  id: "a1b2c3d4-0000-0000-0000-000000000000",
};

export default function AppSettings() {
  const [copied, setCopied] = useState("");

  const agentToken = "marchyo-agent-a1b2c3d4";
  const substituterUrl = "https://cache.marchyo.io";
  const publicKey = "cache.marchyo.io:abc123XYZ0000...=";

  const copy = (val, key) => {
    navigator.clipboard.writeText(val);
    setCopied(key);
    setTimeout(() => setCopied(""), 1500);
  };

  return (
    <div className="animate-fade-in">
      <PageHeader
        title="settings"
        subtitle="Account and Marchyo configuration"
      />

      <div className="max-w-2xl mx-auto p-6 space-y-6">
        {/* Account */}
        <Section title="account" icon={User}>
          <Row label="email" value={EXAMPLE_USER.email} mono />
          <Row label="name" value={EXAMPLE_USER.full_name} />
          <Row label="role" value={EXAMPLE_USER.role} mono />
          <Row
            label="user id"
            value={EXAMPLE_USER.id}
            mono
            copyKey="uid"
            onCopy={copy}
            copied={copied}
          />
        </Section>

        {/* Agent token */}
        <Section title="agent token" icon={Key}>
          <p className="text-xs text-muted-foreground mb-4">
            Use this token to authenticate the{" "}
            <span className="font-mono">marchyo-agent</span> daemon on each
            machine. The agent reports machine status and sync state back to the
            dashboard.
          </p>
          <Row
            label="token"
            value={agentToken}
            mono
            secret
            copyKey="token"
            onCopy={copy}
            copied={copied}
          />
          <div className="mt-3 terminal-block p-3 text-xs">
            <span className="text-primary">❯ </span>
            <span>marchyo agent --token {agentToken}</span>
          </div>
        </Section>

        {/* Remote builders */}
        <Section title="remote builders" icon={Cpu}>
          <p className="text-xs text-muted-foreground mb-4">
            Offload builds to Marchyo's distributed build farm. Add to{" "}
            <span className="font-mono">nix.buildMachines</span> in your
            configuration.
          </p>
          <Row
            label="builder host"
            value="ssh://builder.marchyo.io"
            mono
            copyKey="bhost"
            onCopy={copy}
            copied={copied}
          />
          <Row
            label="ssh key"
            value="~/.ssh/marchyo_builder_ed25519"
            mono
            copyKey="bkey"
            onCopy={copy}
            copied={copied}
          />
          <Row label="systems" value="x86_64-linux aarch64-linux" mono />
          <Row label="max jobs" value="8" mono />
          <div className="mt-3 terminal-block p-3 text-xs space-y-1">
            <div>
              <span className="text-muted-foreground">
                # nix.buildMachines entry
              </span>
            </div>
            <div>
              <span className="text-primary">hostName</span>{" "}
              <span className="text-muted-foreground">= </span>
              <span>"builder.marchyo.io"</span>
              <span className="text-muted-foreground">;</span>
            </div>
            <div>
              <span className="text-primary">sshKey</span>{" "}
              <span className="text-muted-foreground">= </span>
              <span>"~/.ssh/marchyo_builder_ed25519"</span>
              <span className="text-muted-foreground">;</span>
            </div>
            <div>
              <span className="text-primary">systems</span>{" "}
              <span className="text-muted-foreground">= </span>
              <span>[ "x86_64-linux" "aarch64-linux" ]</span>
              <span className="text-muted-foreground">;</span>
            </div>
            <div>
              <span className="text-primary">maxJobs</span>{" "}
              <span className="text-muted-foreground">= </span>
              <span>8</span>
              <span className="text-muted-foreground">;</span>
            </div>
            <div>
              <span className="text-primary">speedFactor</span>{" "}
              <span className="text-muted-foreground">= </span>
              <span>4</span>
              <span className="text-muted-foreground">;</span>
            </div>
            <div>
              <span className="text-primary">supportedFeatures</span>{" "}
              <span className="text-muted-foreground">= </span>
              <span>[ "nixos-test" "benchmark" "big-parallel" ]</span>
              <span className="text-muted-foreground">;</span>
            </div>
          </div>
          <div className="mt-3 px-3 py-2 border border-border bg-muted/30 text-xs font-mono text-muted-foreground">
            <span className="text-copper">// soon</span> — remote builders land
            once the marchyo build farm is live; the config above will just
            work.
          </div>
        </Section>

        {/* Nix cache */}
        <Section title="nix cache / substituter" icon={Cpu}>
          <p className="text-xs text-muted-foreground mb-4">
            Add these to your <span className="font-mono">nix.settings</span> to
            use the Marchyo binary cache. Requires an active account —
            substitutions are verified against your token.
          </p>
          <Row
            label="substituter"
            value={substituterUrl}
            mono
            copyKey="sub"
            onCopy={copy}
            copied={copied}
          />
          <Row
            label="trusted-public-key"
            value={publicKey}
            mono
            copyKey="key"
            onCopy={copy}
            copied={copied}
          />
          <div className="mt-3 terminal-block p-3 text-xs space-y-1">
            <div>
              <span className="text-muted-foreground">
                # nix.settings in your flake
              </span>
            </div>
            <div>
              <span className="text-primary">extra-substituters</span>{" "}
              <span className="text-muted-foreground">= </span>
              <span>"{substituterUrl}"</span>
              <span className="text-muted-foreground">;</span>
            </div>
            <div>
              <span className="text-primary">extra-trusted-public-keys</span>{" "}
              <span className="text-muted-foreground">= </span>
              <span>"{publicKey}"</span>
              <span className="text-muted-foreground">;</span>
            </div>
          </div>
          <div className="mt-3 px-3 py-2 border border-border bg-muted/30 text-xs font-mono text-muted-foreground">
            <span className="text-copper">// soon</span> — cache and remote
            builds land once the marchyo backend is live.
          </div>
        </Section>
      </div>
    </div>
  );
}

function Section({ title, icon: Icon, children }) {
  return (
    <div className="border border-border">
      <div className="px-4 py-3 border-b border-border flex items-center gap-2 bg-muted/30">
        <Icon className="w-3.5 h-3.5 text-muted-foreground" />
        <h2 className="font-mono text-xs font-semibold text-foreground">
          {title}
        </h2>
      </div>
      <div className="p-4 space-y-3">{children}</div>
    </div>
  );
}

function Row({ label, value, mono, secret, copyKey, onCopy, copied }) {
  const [reveal, setReveal] = useState(false);
  const display =
    secret && !reveal ? "•".repeat(Math.min(value.length, 32)) : value;
  return (
    <div className="flex items-center justify-between gap-4 py-1">
      <span className="font-mono text-xs text-muted-foreground w-36 shrink-0">
        {label}
      </span>
      <span
        className={`text-xs flex-1 min-w-0 truncate ${mono ? "font-mono text-foreground" : "text-foreground"}`}
      >
        {display}
      </span>
      <div className="flex items-center gap-1.5 shrink-0">
        {secret && (
          <button
            onClick={() => setReveal(!reveal)}
            className="text-xs text-muted-foreground hover:text-foreground px-1.5 py-0.5 border border-border"
          >
            {reveal ? "hide" : "show"}
          </button>
        )}
        {copyKey && onCopy && (
          <button
            onClick={() => onCopy(value, copyKey)}
            className="p-1 text-muted-foreground hover:text-primary transition-colors border border-border"
          >
            {copied === copyKey ? (
              <Check className="w-3 h-3 text-primary" />
            ) : (
              <Copy className="w-3 h-3" />
            )}
          </button>
        )}
      </div>
    </div>
  );
}

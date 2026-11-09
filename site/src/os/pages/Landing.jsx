import { Link } from "react-router-dom";
import { ArrowRight, ExternalLink } from "lucide-react";
import ThemeToggle from "@/components/ThemeToggle";

// Capabilities live now vs. planned. Rendered as a manual/spec list rather than
// an identical card grid — "cards are lazy answers."
const AVAILABLE = [
  {
    key: "fleet",
    title: "Fleet management",
    desc: "Track every machine — NixOS desktops, macOS laptops, Android phones — from one dashboard. Assign profiles, watch sync status, know the state of each node.",
  },
  {
    key: "profiles",
    title: "Config profiles",
    desc: "Reusable configuration profiles for any platform. Browse the marchyo.* option namespace, toggle features, apply consistent settings across machines.",
  },
  {
    key: "repos",
    title: "Git-backed configs",
    desc: "Your Nix flake repo is the source of truth. marchyo tracks branches and surfaces sync status — you own the config, completely.",
  },
];

const PLANNED = [
  {
    key: "cache",
    title: "Nix cache",
    desc: "Pre-built substitutes so deployments skip compilation for common packages.",
  },
  {
    key: "remote-builds",
    title: "Remote builds",
    desc: "Offload builds to marchyo infrastructure. Target aarch64 from x86_64, keep local machines fast.",
  },
];

const PLATFORMS = [
  { label: "NixOS", desc: "full system configuration" },
  { label: "Home Manager", desc: "user environment management" },
  { label: "nix-darwin", desc: "macOS system config" },
  { label: "nix-on-droid", desc: "Android / Termux environment" },
];

// The hero artifact: a real terminal transcript, not decoration.
const HERO_LINES = [
  { kind: "cmd", text: "marchyo switch --profile workstation" },
  { kind: "out", text: "› evaluating flake.nix ..." },
  { kind: "out", text: "› resolved 312 options" },
  { kind: "out", text: "› building [============================] 100%" },
  { kind: "ok", text: "✓ activation complete — 14 paths changed" },
  { kind: "cmd", text: "marchyo fleet status" },
  { kind: "head", text: "  HOSTNAME       PLATFORM      PROFILE       STATUS" },
  {
    kind: "row-ok",
    text: "  thinkpad-x1    nixos         workstation   ● online",
  },
  {
    kind: "row-ok",
    text: "  macbook-m3     nix-darwin    dev-light     ● online",
  },
  {
    kind: "row-warn",
    text: "  pixel-9        nix-on-droid  mobile        ○ stale",
  },
];

// The "how it works" walkthrough — an actual session, no numbered scaffolding.
const WALKTHROUGH = [
  {
    kind: "comment",
    text: "// 1. start from the flake template — your config, your repo",
  },
  {
    kind: "cmd",
    text: "git clone https://github.com/Jylhis/marchyo && cd marchyo",
  },
  {
    kind: "comment",
    text: "// 2. declare each host with a platform target and profile",
  },
  {
    kind: "cmd",
    text: "$EDITOR flake.nix   # nixosConfigurations, darwinConfigurations, ...",
  },
  {
    kind: "comment",
    text: "// 3. connect the repo for cache, remote builds, fleet visibility",
  },
  { kind: "cmd", text: "marchyo link ." },
  { kind: "ok", text: "✓ linked — 3 hosts discovered" },
  {
    kind: "comment",
    text: "// 4. converge every machine to its declared state",
  },
  { kind: "cmd", text: "marchyo switch --all" },
];

function TerminalLine({ line }) {
  const cls = {
    cmd: "text-ink",
    out: "text-ink-muted",
    ok: "text-status-ok",
    head: "text-ink-faint",
    "row-ok": "text-ink-muted",
    "row-warn": "text-ink-muted",
    comment: "text-ink-faint",
  }[line.kind];
  return (
    <div className="font-mono text-xs leading-6 whitespace-pre">
      {line.kind === "cmd" && <span className="text-copper">❯ </span>}
      <span className={cls}>{line.text}</span>
    </div>
  );
}

function Terminal({ title, lines }) {
  return (
    <div className="terminal-block overflow-x-auto">
      <div className="flex items-center gap-2 px-4 py-2.5 border-b border-border">
        <span className="w-2 h-2 bg-status-err" aria-hidden />
        <span className="w-2 h-2 bg-status-warn" aria-hidden />
        <span className="w-2 h-2 bg-status-ok" aria-hidden />
        <span className="ml-2 text-ink-faint text-xs font-mono">{title}</span>
      </div>
      <div className="p-5 space-y-0.5">
        {lines.map((line, i) => (
          <TerminalLine key={i} line={line} />
        ))}
      </div>
    </div>
  );
}

export default function Landing() {
  return (
    <div className="min-h-screen bg-background">
      <nav className="border-b border-border bg-background sticky top-0 z-50">
        <div className="max-w-5xl mx-auto px-6 h-14 flex items-center justify-between">
          <span className="font-mono font-semibold text-sm tracking-tight text-ink-heading">
            marchyo<span className="text-copper animate-blink">_</span>
          </span>
          <div className="flex items-center gap-5">
            <a
              href="https://github.com/Jylhis/marchyo"
              target="_blank"
              rel="noopener noreferrer"
              className="font-mono text-xs text-ink-muted hover:text-copper transition-colors flex items-center gap-1"
            >
              github <ExternalLink className="w-3 h-3" />
            </a>
            <Link
              to="/fleet"
              className="font-mono text-xs font-medium px-3 py-1.5 bg-primary text-primary-foreground hover:bg-copper-hover transition-colors"
            >
              open dashboard
            </Link>
            <ThemeToggle />
          </div>
        </div>
      </nav>

      <section className="border-b border-border">
        <div className="max-w-5xl mx-auto px-6 pt-20 pb-16 lg:pt-28">
          <div className="max-w-2xl">
            <p className="font-mono text-xs text-copper mb-6">
              // personal os framework · built on nix
            </p>
            <h1 className="font-mono text-4xl sm:text-5xl lg:text-6xl font-bold text-ink-heading leading-[1.1] tracking-tight text-balance mb-6">
              Your operating system,{" "}
              <span className="text-copper">declaratively yours.</span>
            </h1>
            <p className="text-lg text-ink-muted leading-relaxed text-pretty mb-8 max-w-xl">
              marchyo manages NixOS, Home Manager, nix-darwin, and nix-on-droid
              from one configuration layer. One codebase, every machine — no
              lock-in, no drift.
            </p>
            <div className="flex items-center gap-3 flex-wrap">
              <Link
                to="/fleet"
                className="inline-flex items-center gap-2 px-5 py-2.5 bg-primary text-primary-foreground text-sm font-mono font-medium hover:bg-copper-hover transition-colors"
              >
                open dashboard <ArrowRight className="w-4 h-4" />
              </Link>
              <a
                href="https://github.com/Jylhis/marchyo"
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-2 px-5 py-2.5 border border-border text-sm font-mono font-medium text-ink hover:border-copper hover:text-copper transition-colors"
              >
                view on github <ExternalLink className="w-3.5 h-3.5" />
              </a>
            </div>
          </div>
        </div>

        <div className="max-w-5xl mx-auto px-6 pb-16">
          <Terminal title="marchyo-cli — workstation" lines={HERO_LINES} />
        </div>
      </section>

      {/* spec row, not cards */}
      <section className="border-b border-border bg-canvas-subtle">
        <div className="max-w-5xl mx-auto px-6 py-12">
          <div className="flex flex-col sm:flex-row sm:items-baseline gap-x-8 gap-y-6">
            <p className="font-mono text-sm text-ink-faint shrink-0 sm:w-32">
              runs on
            </p>
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-x-6 gap-y-5 flex-1">
              {PLATFORMS.map((p) => (
                <div key={p.label}>
                  <div className="font-mono text-sm font-medium text-ink-heading">
                    {p.label}
                  </div>
                  <div className="text-sm text-ink-muted">{p.desc}</div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* manual/spec list, asymmetric */}
      <section className="border-b border-border">
        <div className="max-w-5xl mx-auto px-6 py-20">
          <h2 className="text-3xl font-bold text-ink-heading text-balance mb-3">
            One control plane for every machine.
          </h2>
          <p className="text-base text-ink-muted text-pretty max-w-xl mb-12">
            Everything below is wired to your flake. Read the config, change it,
            watch it converge.
          </p>

          <div className="border-t border-border">
            {AVAILABLE.map((f) => (
              <div
                key={f.key}
                className="grid md:grid-cols-[9rem_1fr] gap-2 md:gap-8 py-6 border-b border-border"
              >
                <div className="font-mono text-sm text-copper">
                  <span className="text-decorator">›</span> {f.title}
                </div>
                <p className="text-base text-ink-muted leading-relaxed text-pretty max-w-2xl">
                  {f.desc}
                </p>
              </div>
            ))}
          </div>

          <div className="mt-12">
            <p className="font-mono text-xs text-ink-faint mb-5">
              // on the roadmap
            </p>
            <div className="grid sm:grid-cols-2 gap-x-8 gap-y-5">
              {PLANNED.map((f) => (
                <div key={f.key} className="flex gap-3">
                  <span className="font-mono text-sm text-decorator shrink-0">
                    ▸
                  </span>
                  <div>
                    <div className="font-mono text-sm text-ink-heading">
                      {f.title} <span className="text-ink-faint">— soon</span>
                    </div>
                    <p className="text-sm text-ink-muted text-pretty">
                      {f.desc}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      <section className="border-b border-border bg-canvas-subtle">
        <div className="max-w-5xl mx-auto px-6 py-20">
          <h2 className="text-3xl font-bold text-ink-heading text-balance mb-3">
            Nix all the way down.
          </h2>
          <p className="text-base text-ink-muted text-pretty max-w-xl mb-10">
            Four commands from an empty directory to a converged fleet.
          </p>
          <Terminal title="getting started" lines={WALKTHROUGH} />
        </div>
      </section>

      {/* CTA */}
      <section className="max-w-5xl mx-auto px-6 py-24 text-center">
        <h2 className="text-3xl font-bold text-ink-heading text-balance mb-4">
          Ready to declare your OS?
        </h2>
        <p className="text-base text-ink-muted text-pretty mb-8 max-w-md mx-auto">
          Bring your existing Nix config or start from the template. It stays
          your repo either way.
        </p>
        <div className="flex items-center justify-center gap-3 flex-wrap">
          <Link
            to="/fleet"
            className="inline-flex items-center gap-2 px-6 py-2.5 bg-primary text-primary-foreground text-sm font-mono font-medium hover:bg-copper-hover transition-colors"
          >
            open dashboard <ArrowRight className="w-4 h-4" />
          </Link>
        </div>
      </section>

      <footer className="border-t border-border bg-canvas-subtle">
        <div className="max-w-5xl mx-auto px-6 py-6 flex items-center justify-between text-xs text-ink-muted">
          <span className="font-mono">
            marchyo<span className="text-copper">_</span>
          </span>
          <div className="flex items-center gap-4 font-mono">
            <a
              href="https://github.com/Jylhis/marchyo"
              target="_blank"
              rel="noopener noreferrer"
              className="hover:text-copper transition-colors"
            >
              github
            </a>
          </div>
        </div>
      </footer>
    </div>
  );
}

// Neutral mono tags — differentiated by name, not a rainbow of tints
// (single copper accent is reserved for interactive/selected surfaces).
const PLATFORM_MAP = {
  nixos: "NixOS",
  "home-manager": "Home Manager",
  "nix-darwin": "nix-darwin",
  "nix-on-droid": "nix-on-droid",
  all: "all platforms",
};

export default function PlatformBadge({ platform }) {
  const label = PLATFORM_MAP[platform] || PLATFORM_MAP.all;
  return (
    <span className="inline-flex items-center px-2 py-0.5 font-mono text-xs border border-border bg-canvas-subtle text-ink-muted">
      {label}
    </span>
  );
}

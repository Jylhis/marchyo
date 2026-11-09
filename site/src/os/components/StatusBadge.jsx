// ANSI-style status: a token-colored dot carries meaning; the label stays ink.
// No colored tint backgrounds (avoids gray-on-color), no reflexive pulse.
const MAP = {
  online: { dot: "bg-status-ok", label: "online" },
  synced: { dot: "bg-status-ok", label: "synced" },
  stale: { dot: "bg-status-warn", label: "stale" },
  pending: { dot: "bg-status-warn", label: "pending" },
  error: { dot: "bg-status-err", label: "error" },
  unknown: { dot: "bg-decorator", label: "unknown" },
  disconnected: { dot: "bg-decorator", label: "disconnected" },
};

export default function StatusBadge({ status }) {
  const s = MAP[status] || MAP.unknown;
  return (
    <span className="inline-flex items-center gap-1.5 px-2 py-0.5 font-mono text-xs border border-border text-ink-muted">
      <span className={`w-1.5 h-1.5 rounded-full ${s.dot}`} />
      {s.label}
    </span>
  );
}

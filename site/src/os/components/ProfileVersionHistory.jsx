import { useState, useEffect } from "react";
import { Clock, RotateCcw, ChevronDown, ChevronRight } from "lucide-react";
import { formatDistanceToNow } from "date-fns";

// Version history is stored locally in localStorage keyed by profile id
const STORAGE_KEY = "marchyo_profile_versions";

export function saveProfileVersion(profile) {
  if (!profile?.id) return;
  const all = getVersions();
  if (!all[profile.id]) all[profile.id] = [];
  // Don't save duplicate consecutive snapshots
  const last = all[profile.id][0];
  if (last && JSON.stringify(last.snapshot) === JSON.stringify(profile)) return;
  all[profile.id].unshift({
    id: Date.now(),
    savedAt: new Date().toISOString(),
    snapshot: { ...profile },
    label: profile.name,
  });
  // Keep at most 20 versions
  all[profile.id] = all[profile.id].slice(0, 20);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(all));
}

function getVersions() {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}");
  } catch {
    return {};
  }
}

export default function ProfileVersionHistory({ profile, onRevert }) {
  const [versions, setVersions] = useState([]);
  const [expanded, setExpanded] = useState(null);

  useEffect(() => {
    if (!profile?.id) return;
    const all = getVersions();
    setVersions(all[profile.id] || []);
  }, [profile]);

  if (versions.length === 0) {
    return (
      <div className="p-8 text-center text-xs text-muted-foreground font-mono">
        no version history yet — save the profile to create the first snapshot
      </div>
    );
  }

  const handleRevert = (v) => {
    if (
      window.confirm(
        `Revert to version saved ${formatDistanceToNow(new Date(v.savedAt), { addSuffix: true })}?`,
      )
    ) {
      onRevert(v.snapshot);
    }
  };

  return (
    <div className="divide-y divide-border">
      {versions.map((v, idx) => {
        const isOpen = expanded === v.id;
        const enabledCount = v.snapshot.enabled_options?.length || 0;
        const prev = versions[idx + 1];
        const prevEnabled = prev?.snapshot.enabled_options?.length || 0;
        const diff = enabledCount - prevEnabled;
        return (
          <div key={v.id}>
            <div className="flex items-center gap-3 px-5 py-3 hover:bg-muted/30 transition-colors">
              <button
                onClick={() => setExpanded(isOpen ? null : v.id)}
                className="text-muted-foreground hover:text-foreground transition-colors"
              >
                {isOpen ? (
                  <ChevronDown className="w-3.5 h-3.5" />
                ) : (
                  <ChevronRight className="w-3.5 h-3.5" />
                )}
              </button>
              <Clock className="w-3.5 h-3.5 text-muted-foreground shrink-0" />
              <div className="flex-1 min-w-0">
                <div className="font-mono text-xs text-foreground">
                  {formatDistanceToNow(new Date(v.savedAt), {
                    addSuffix: true,
                  })}
                  {idx === 0 && (
                    <span className="ml-2 text-xs bg-primary text-primary-foreground px-1 font-mono">
                      latest
                    </span>
                  )}
                </div>
                <div className="text-xs text-muted-foreground mt-0.5">
                  {enabledCount} options enabled
                  {idx > 0 && diff !== 0 && (
                    <span
                      className={`ml-2 font-mono ${diff > 0 ? "text-status-ok" : "text-status-err"}`}
                    >
                      {diff > 0 ? `+${diff}` : diff}
                    </span>
                  )}
                </div>
              </div>
              {idx > 0 && (
                <button
                  onClick={() => handleRevert(v)}
                  className="flex items-center gap-1 text-xs text-muted-foreground hover:text-primary border border-border px-2 py-1 transition-colors font-mono shrink-0"
                >
                  <RotateCcw className="w-3 h-3" /> revert
                </button>
              )}
            </div>
            {isOpen && (
              <div className="px-12 pb-4">
                <div className="terminal-block p-3 text-xs space-y-1">
                  <div>
                    <span className="text-muted-foreground">name: </span>
                    <span>{v.snapshot.name}</span>
                  </div>
                  <div>
                    <span className="text-muted-foreground">platform: </span>
                    <span>{v.snapshot.platform}</span>
                  </div>
                  <div>
                    <span className="text-muted-foreground">
                      enabled options ({enabledCount}):{" "}
                    </span>
                  </div>
                  {(v.snapshot.enabled_options || []).map((o) => (
                    <div key={o} className="pl-2 text-primary">
                      · {o}
                    </div>
                  ))}
                  {enabledCount === 0 && (
                    <div className="pl-2 text-muted-foreground italic">
                      none
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

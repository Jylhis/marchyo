import { useState } from "react";
import { X, Server, GitBranch, Clock, Tag } from "lucide-react";
import StatusBadge from "@/components/StatusBadge";
import PlatformBadge from "@/components/PlatformBadge";
import MachineDeploymentHistory from "@/components/MachineDeploymentHistory";
import { formatDistanceToNow } from "date-fns";

export default function MachineDetailDrawer({
  machine,
  profile,
  repo,
  onClose,
  onEdit,
}) {
  const [tab, setTab] = useState("info");

  if (!machine) return null;

  return (
    <div className="fixed inset-0 z-40 flex justify-end">
      {/* backdrop */}
      <div className="absolute inset-0 bg-black/30" onClick={onClose} />
      {/* panel */}
      <div className="relative w-full max-w-md bg-background border-l border-border flex flex-col shadow-2xl animate-fade-in">
        {/* header */}
        <div className="flex items-center justify-between px-5 py-4 border-b border-border shrink-0">
          <div className="flex items-center gap-2 min-w-0">
            <Server className="w-4 h-4 text-muted-foreground shrink-0" />
            <span className="font-mono text-sm font-semibold text-foreground truncate">
              {machine.hostname}
            </span>
            {machine.arch && (
              <span className="font-mono text-xs text-muted-foreground">
                ({machine.arch})
              </span>
            )}
          </div>
          <div className="flex items-center gap-2 shrink-0">
            <button
              onClick={onEdit}
              className="text-xs font-mono text-muted-foreground hover:text-foreground border border-border px-2 py-1 transition-colors"
            >
              edit
            </button>
            <button
              onClick={onClose}
              className="text-muted-foreground hover:text-foreground transition-colors ml-1"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* tabs */}
        <div className="flex border-b border-border shrink-0">
          {["info", "deployments"].map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className={`px-4 py-2.5 text-xs font-mono font-medium transition-colors border-b-2 -mb-px ${
                tab === t
                  ? "border-copper text-copper"
                  : "border-transparent text-muted-foreground hover:text-foreground"
              }`}
            >
              {t}
            </button>
          ))}
        </div>

        <div className="flex-1 overflow-y-auto">
          {tab === "info" && (
            <div className="p-5 space-y-5">
              {/* status row */}
              <div className="flex items-center justify-between">
                <StatusBadge status={machine.status || "unknown"} />
                {machine.last_seen && (
                  <span className="text-xs text-muted-foreground flex items-center gap-1">
                    <Clock className="w-3 h-3" />
                    {formatDistanceToNow(new Date(machine.last_seen), {
                      addSuffix: true,
                    })}
                  </span>
                )}
              </div>

              {/* details grid */}
              <div className="space-y-3">
                <InfoRow label="platform">
                  <PlatformBadge platform={machine.platform} />
                </InfoRow>
                <InfoRow label="arch">
                  <span className="font-mono text-xs">
                    {machine.arch || "—"}
                  </span>
                </InfoRow>
                {machine.description && (
                  <InfoRow label="description">
                    <span className="text-xs">{machine.description}</span>
                  </InfoRow>
                )}
                <InfoRow label="profile">
                  {profile ? (
                    <span className="font-mono text-xs text-copper">
                      {profile.name}
                    </span>
                  ) : (
                    <span className="text-xs italic text-muted-foreground">
                      none
                    </span>
                  )}
                </InfoRow>
                <InfoRow label="repo">
                  {repo ? (
                    <span className="font-mono text-xs flex items-center gap-1">
                      <GitBranch className="w-3 h-3" />
                      {repo.name || repo.url?.split("/").pop()}
                    </span>
                  ) : (
                    <span className="text-xs italic text-muted-foreground">
                      none
                    </span>
                  )}
                </InfoRow>
                <InfoRow label="machine id">
                  <span className="font-mono text-xs text-muted-foreground truncate">
                    {machine.id}
                  </span>
                </InfoRow>
              </div>

              {/* tags */}
              {(machine.tags || []).length > 0 && (
                <div>
                  <div className="font-mono text-xs text-muted-foreground mb-2 flex items-center gap-1">
                    <Tag className="w-3 h-3" /> tags
                  </div>
                  <div className="flex flex-wrap gap-1.5">
                    {machine.tags.map((tag) => (
                      <span
                        key={tag}
                        className="font-mono text-xs bg-copper-subtle text-copper px-2 py-0.5"
                      >
                        {tag}
                      </span>
                    ))}
                  </div>
                </div>
              )}

              {/* profile options preview */}
              {profile && (profile.enabled_options || []).length > 0 && (
                <div>
                  <div className="font-mono text-xs text-muted-foreground mb-2">
                    enabled options ({profile.enabled_options.length})
                  </div>
                  <div className="terminal-block p-3 max-h-40 overflow-y-auto space-y-0.5">
                    {profile.enabled_options.map((opt) => (
                      <div
                        key={opt}
                        className="font-mono text-xs text-foreground"
                      >
                        {opt}
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}

          {tab === "deployments" && (
            <div>
              <div className="px-5 py-3 border-b border-border">
                <p className="text-xs text-muted-foreground font-mono">
                  recent configuration updates and sync events
                </p>
              </div>
              <MachineDeploymentHistory
                machineId={machine.id}
                hostname={machine.hostname}
              />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function InfoRow({ label, children }) {
  return (
    <div className="flex items-start gap-3">
      <span className="font-mono text-xs text-muted-foreground w-24 shrink-0 pt-0.5">
        {label}
      </span>
      <div className="min-w-0 flex-1">{children}</div>
    </div>
  );
}

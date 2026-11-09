import { useState, useEffect } from "react";
import {
  CheckCircle,
  XCircle,
  AlertCircle,
  RefreshCw,
  Clock,
} from "lucide-react";
import { formatDistanceToNow } from "date-fns";

const STORAGE_KEY = "marchyo_deploy_log";
const MAX_PER_MACHINE = 30;

// Call this from anywhere to record a deployment event
export function recordDeployment(
  machineId,
  hostname,
  { status = "success", profile, message, syncType = "config-update" } = {},
) {
  const all = JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}");
  const entry = {
    id: Date.now() + Math.random().toString(36).slice(2),
    ts: new Date().toISOString(),
    status, // 'success' | 'error' | 'warning' | 'syncing'
    profile: profile || null,
    message:
      message ||
      (status === "success"
        ? "Configuration applied successfully"
        : "Deployment failed"),
    syncType, // 'config-update' | 'profile-change' | 'manual-sync'
  };
  const prev = all[machineId] || [];
  all[machineId] = [entry, ...prev].slice(0, MAX_PER_MACHINE);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(all));
  return entry;
}

export function getMachineHistory(machineId) {
  const all = JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}");
  return all[machineId] || [];
}

// Seed some demo history for a machine if it has none
export function seedDemoHistory(machineId, hostname) {
  if (getMachineHistory(machineId).length > 0) return;
  const all = JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}");
  const now = Date.now();
  all[machineId] = [
    {
      id: "demo-1",
      ts: new Date(now - 1000 * 60 * 12).toISOString(),
      status: "success",
      profile: "workstation",
      message: "Configuration applied successfully",
      syncType: "config-update",
    },
    {
      id: "demo-2",
      ts: new Date(now - 1000 * 60 * 60 * 2).toISOString(),
      status: "warning",
      profile: "workstation",
      message: "nix-env: 1 collision in /nix/store (non-fatal)",
      syncType: "config-update",
    },
    {
      id: "demo-3",
      ts: new Date(now - 1000 * 60 * 60 * 5).toISOString(),
      status: "success",
      profile: "base",
      message: 'Profile changed to "workstation"',
      syncType: "profile-change",
    },
    {
      id: "demo-4",
      ts: new Date(now - 1000 * 60 * 60 * 24).toISOString(),
      status: "error",
      profile: "base",
      message: "error: attribute 'pkgs.vscodium' missing",
      syncType: "config-update",
    },
    {
      id: "demo-5",
      ts: new Date(now - 1000 * 60 * 60 * 25).toISOString(),
      status: "success",
      profile: "base",
      message: "Manual sync triggered",
      syncType: "manual-sync",
    },
  ];
  localStorage.setItem(STORAGE_KEY, JSON.stringify(all));
}

const STATUS_ICON = {
  success: <CheckCircle className="w-3.5 h-3.5 text-status-ok shrink-0" />,
  error: <XCircle className="w-3.5 h-3.5 text-status-err shrink-0" />,
  warning: (
    <AlertCircle className="w-3.5 h-3.5 text-status-warn shrink-0" />
  ),
  syncing: (
    <RefreshCw className="w-3.5 h-3.5 text-status-info shrink-0 animate-spin" />
  ),
};

const SYNC_TYPE_LABEL = {
  "config-update": "config update",
  "profile-change": "profile change",
  "manual-sync": "manual sync",
};

export default function MachineDeploymentHistory({ machineId, hostname }) {
  const [entries, setEntries] = useState([]);

  useEffect(() => {
    if (!machineId) return;
    seedDemoHistory(machineId, hostname);
    setEntries(getMachineHistory(machineId));
  }, [machineId]);

  if (!entries.length) {
    return (
      <div className="p-8 text-center text-xs text-muted-foreground font-mono">
        no deployment history yet
      </div>
    );
  }

  return (
    <div className="divide-y divide-border">
      {entries.map((entry) => (
        <div key={entry.id} className="flex items-start gap-3 px-5 py-3">
          <div className="mt-0.5">
            {STATUS_ICON[entry.status] || STATUS_ICON.success}
          </div>
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2 flex-wrap">
              <span
                className={`font-mono text-xs font-medium ${
                  entry.status === "error"
                    ? "text-status-err"
                    : entry.status === "warning"
                      ? "text-status-warn"
                      : entry.status === "syncing"
                        ? "text-status-info"
                        : "text-foreground"
                }`}
              >
                {entry.status}
              </span>
              <span className="text-xs text-muted-foreground">·</span>
              <span className="font-mono text-xs text-muted-foreground">
                {SYNC_TYPE_LABEL[entry.syncType] || entry.syncType}
              </span>
              {entry.profile && (
                <>
                  <span className="text-xs text-muted-foreground">·</span>
                  <span className="font-mono text-xs text-copper">
                    {entry.profile}
                  </span>
                </>
              )}
            </div>
            <div className="text-xs text-foreground mt-0.5">
              {entry.message}
            </div>
            <div className="flex items-center gap-1 mt-1 text-xs text-muted-foreground">
              <Clock className="w-3 h-3" />
              {formatDistanceToNow(new Date(entry.ts), { addSuffix: true })}
              <span className="ml-1 font-mono text-xs opacity-50">
                {new Date(entry.ts).toLocaleTimeString()}
              </span>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}

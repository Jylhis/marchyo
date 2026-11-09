import { useState, useEffect } from "react";
import { X } from "lucide-react";
import MachineTagInput from "@/components/MachineTagInput";

const PLATFORMS = ["nixos", "home-manager", "nix-darwin", "nix-on-droid"];
const ARCHES = ["x86_64", "aarch64", "armv7l"];
const STATUSES = ["online", "stale", "unknown"];

const EMPTY = {
  hostname: "",
  platform: "nixos",
  arch: "x86_64",
  status: "unknown",
  description: "",
  profile_id: "",
  git_repo_id: "",
  tags: [],
};

export default function MachineModal({
  open,
  onClose,
  onSave,
  machine,
  profiles,
  repos,
}) {
  const [form, setForm] = useState(EMPTY);

  useEffect(() => {
    if (machine) {
      setForm({
        hostname: machine.hostname || "",
        platform: machine.platform || "nixos",
        arch: machine.arch || "x86_64",
        status: machine.status || "unknown",
        description: machine.description || "",
        profile_id: machine.profile_id || "",
        git_repo_id: machine.git_repo_id || "",
        tags: machine.tags || [],
      });
    } else {
      setForm(EMPTY);
    }
  }, [machine, open]);

  if (!open) return null;

  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }));

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50">
      <div className="bg-card border border-border w-full max-w-md shadow-xl">
        <div className="flex items-center justify-between px-5 py-4 border-b border-border">
          <h2 className="font-mono text-sm font-semibold">
            {machine ? "edit machine" : "add machine"}
          </h2>
          <button
            onClick={onClose}
            className="text-muted-foreground hover:text-foreground"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
        <div className="p-5 space-y-4">
          <Field label="hostname" required>
            <input
              value={form.hostname}
              onChange={(e) => set("hostname", e.target.value)}
              className="w-full border border-border px-3 py-2 font-mono text-sm focus:outline-hidden focus:border-copper"
              placeholder="thinkpad-x1"
            />
          </Field>
          <div className="grid grid-cols-2 gap-3">
            <Field label="platform">
              <select
                value={form.platform}
                onChange={(e) => set("platform", e.target.value)}
                className="w-full border border-border px-3 py-2 font-mono text-sm focus:outline-hidden focus:border-copper bg-background"
              >
                {PLATFORMS.map((p) => (
                  <option key={p} value={p}>
                    {p}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="arch">
              <select
                value={form.arch}
                onChange={(e) => set("arch", e.target.value)}
                className="w-full border border-border px-3 py-2 font-mono text-sm focus:outline-hidden focus:border-copper bg-background"
              >
                {ARCHES.map((a) => (
                  <option key={a} value={a}>
                    {a}
                  </option>
                ))}
              </select>
            </Field>
          </div>
          <Field label="status">
            <select
              value={form.status}
              onChange={(e) => set("status", e.target.value)}
              className="w-full border border-border px-3 py-2 font-mono text-sm focus:outline-hidden focus:border-copper bg-background"
            >
              {STATUSES.map((s) => (
                <option key={s} value={s}>
                  {s}
                </option>
              ))}
            </select>
          </Field>
          <Field label="tags">
            <MachineTagInput
              tags={form.tags}
              onChange={(v) => set("tags", v)}
            />
          </Field>
          <Field label="config profile">
            <select
              value={form.profile_id}
              onChange={(e) => set("profile_id", e.target.value)}
              className="w-full border border-border px-3 py-2 font-mono text-sm focus:outline-hidden focus:border-copper bg-background"
            >
              <option value="">— none —</option>
              {profiles.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
          </Field>
          <Field label="git repo">
            <select
              value={form.git_repo_id}
              onChange={(e) => set("git_repo_id", e.target.value)}
              className="w-full border border-border px-3 py-2 font-mono text-sm focus:outline-hidden focus:border-copper bg-background"
            >
              <option value="">— none —</option>
              {repos.map((r) => (
                <option key={r.id} value={r.id}>
                  {r.name || r.url}
                </option>
              ))}
            </select>
          </Field>
          <Field label="description">
            <input
              value={form.description}
              onChange={(e) => set("description", e.target.value)}
              className="w-full border border-border px-3 py-2 text-sm focus:outline-hidden focus:border-copper"
              placeholder="optional note"
            />
          </Field>
        </div>
        <div className="px-5 py-4 border-t border-border flex justify-end gap-2">
          <button
            onClick={onClose}
            className="px-4 py-2 text-xs border border-border text-muted-foreground hover:text-foreground transition-colors"
          >
            cancel
          </button>
          <button
            onClick={() => onSave(form)}
            disabled={!form.hostname}
            className="px-4 py-2 text-xs bg-foreground text-background hover:bg-copper-hover transition-colors disabled:opacity-40"
          >
            {machine ? "save changes" : "add machine"}
          </button>
        </div>
      </div>
    </div>
  );
}

function Field({ label, required, children }) {
  return (
    <div>
      <label className="block font-mono text-xs text-muted-foreground mb-1.5">
        {label}
        {required && <span className="text-copper ml-0.5">*</span>}
      </label>
      {children}
    </div>
  );
}

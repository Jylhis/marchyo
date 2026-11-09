import { useState, useEffect } from "react";
import { X, Eye, EyeOff } from "lucide-react";

export default function RepoModal({ open, onClose, onSave, repo }) {
  const [form, setForm] = useState({
    name: "",
    url: "",
    branch: "main",
    token: "",
  });
  const [showToken, setShowToken] = useState(false);

  useEffect(() => {
    if (repo) {
      setForm({
        name: repo.name || "",
        url: repo.url || "",
        branch: repo.branch || "main",
        token: "",
      });
    } else {
      setForm({ name: "", url: "", branch: "main", token: "" });
    }
    setShowToken(false);
  }, [repo, open]);

  if (!open) return null;
  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }));

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50">
      <div className="bg-card border border-border w-full max-w-md shadow-xl">
        <div className="flex items-center justify-between px-5 py-4 border-b border-border">
          <h2 className="font-mono text-sm font-semibold">
            {repo ? "edit repo" : "connect repo"}
          </h2>
          <button
            onClick={onClose}
            className="text-muted-foreground hover:text-foreground"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
        <div className="p-5 space-y-4">
          <Field label="display name">
            <input
              value={form.name}
              onChange={(e) => set("name", e.target.value)}
              className="w-full border border-border px-3 py-2 font-mono text-sm focus:outline-hidden focus:border-copper"
              placeholder="my-nixos-config"
            />
          </Field>
          <Field label="repo url" required>
            <input
              value={form.url}
              onChange={(e) => set("url", e.target.value)}
              className="w-full border border-border px-3 py-2 font-mono text-sm focus:outline-hidden focus:border-copper"
              placeholder="https://github.com/user/nixos-config"
            />
          </Field>
          <Field label="branch">
            <input
              value={form.branch}
              onChange={(e) => set("branch", e.target.value)}
              className="w-full border border-border px-3 py-2 font-mono text-sm focus:outline-hidden focus:border-copper"
              placeholder="main"
            />
          </Field>
          <Field label="access token (optional)">
            <div className="relative">
              <input
                type={showToken ? "text" : "password"}
                value={form.token}
                onChange={(e) => set("token", e.target.value)}
                className="w-full border border-border px-3 py-2 pr-10 font-mono text-sm focus:outline-hidden focus:border-copper"
                placeholder="ghp_... (for private repos)"
              />
              <button
                onClick={() => setShowToken(!showToken)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
              >
                {showToken ? (
                  <EyeOff className="w-3.5 h-3.5" />
                ) : (
                  <Eye className="w-3.5 h-3.5" />
                )}
              </button>
            </div>
            <p className="text-xs text-muted-foreground mt-1">
              Stored securely. Not required for public repos.
            </p>
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
            disabled={!form.url}
            className="px-4 py-2 text-xs bg-foreground text-background hover:bg-copper-hover transition-colors disabled:opacity-40"
          >
            {repo ? "save changes" : "connect repo"}
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

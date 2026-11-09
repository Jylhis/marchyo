import { useState } from "react";
import { X, Layers } from "lucide-react";
import { api } from "@/api/client";

export default function SaveTemplateModal({
  open,
  onClose,
  options,
  platform,
  onSaved,
}) {
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [saving, setSaving] = useState(false);

  if (!open) return null;

  const handleSave = async () => {
    if (!name.trim()) return;
    setSaving(true);
    await api.entities.OptionTemplate.create({
      name: name.trim(),
      description: description.trim(),
      platform: platform || "all",
      options,
    });
    setSaving(false);
    setName("");
    setDescription("");
    onSaved?.();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center p-4 bg-black/50">
      <div className="bg-card border border-border w-full max-w-sm shadow-xl">
        <div className="flex items-center justify-between px-5 py-4 border-b border-border">
          <div className="flex items-center gap-2">
            <Layers className="w-4 h-4 text-copper" />
            <h2 className="font-mono text-sm font-semibold">
              save as template
            </h2>
          </div>
          <button
            onClick={onClose}
            className="text-muted-foreground hover:text-foreground"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
        <div className="p-5 space-y-4">
          <p className="text-xs text-muted-foreground">
            Saving{" "}
            <span className="font-mono text-copper">
              {options.length} options
            </span>{" "}
            as a reusable template.
          </p>
          <div>
            <label className="block font-mono text-xs text-muted-foreground mb-1.5">
              template name <span className="text-copper">*</span>
            </label>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="base-desktop"
              className="w-full border border-border px-3 py-2 font-mono text-sm focus:outline-hidden focus:border-copper"
            />
          </div>
          <div>
            <label className="block font-mono text-xs text-muted-foreground mb-1.5">
              description
            </label>
            <input
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="optional note"
              className="w-full border border-border px-3 py-2 text-sm focus:outline-hidden focus:border-copper"
            />
          </div>
        </div>
        <div className="px-5 py-4 border-t border-border flex justify-end gap-2">
          <button
            onClick={onClose}
            className="px-4 py-2 text-xs border border-border text-muted-foreground hover:text-foreground transition-colors"
          >
            cancel
          </button>
          <button
            onClick={handleSave}
            disabled={!name.trim() || saving}
            className="px-4 py-2 text-xs bg-foreground text-background hover:bg-copper-hover transition-colors disabled:opacity-40"
          >
            {saving ? "saving…" : "save template"}
          </button>
        </div>
      </div>
    </div>
  );
}

import { useState, useEffect, useMemo } from "react";
import {
  X,
  Search,
  Check,
  CheckSquare,
  Square,
  ToggleLeft,
  ToggleRight,
  Layers,
  ChevronDown,
  Code,
  GitBranch,
} from "lucide-react";
import PlatformBadge from "@/components/PlatformBadge";
import SaveTemplateModal from "@/components/SaveTemplateModal";
import NixExportModal from "@/components/NixExportModal";
import OptionDependencyGraph from "@/components/OptionDependencyGraph";
import ProfileVersionHistory, {
  saveProfileVersion,
} from "@/components/ProfileVersionHistory";
import { api } from "@/api/client";

const PLATFORMS = [
  "nixos",
  "home-manager",
  "nix-darwin",
  "nix-on-droid",
  "all",
];

export default function ProfileModal({
  open,
  onClose,
  onSave,
  profile,
  options,
}) {
  const [form, setForm] = useState({
    name: "",
    platform: "nixos",
    description: "",
    tags: "",
    options: {},
    enabled_options: [],
  });
  const [tab, setTab] = useState("general");
  const [search, setSearch] = useState("");
  const [selected, setSelected] = useState(new Set());
  const [templates, setTemplates] = useState([]);
  const [showTemplates, setShowTemplates] = useState(false);
  const [saveTemplateOpen, setSaveTemplateOpen] = useState(false);
  const [exportOpen, setExportOpen] = useState(false);

  useEffect(() => {
    if (profile) {
      setForm({
        name: profile.name || "",
        platform: profile.platform || "nixos",
        description: profile.description || "",
        tags: (profile.tags || []).join(", "),
        options: profile.options || {},
        enabled_options: profile.enabled_options || [],
      });
    } else {
      setForm({
        name: "",
        platform: "nixos",
        description: "",
        tags: "",
        options: {},
        enabled_options: [],
      });
    }
    setTab("general");
    setSearch("");
    setSelected(new Set());
    setShowTemplates(false);
    api.entities.OptionTemplate.list()
      .then(setTemplates)
      .catch(() => {});
  }, [profile, open]);

  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }));

  const filteredOptions = options.filter((o) => {
    const matchPlatform =
      form.platform === "all" || (o.platforms || []).includes(form.platform);
    const matchSearch =
      !search ||
      o.name.toLowerCase().includes(search.toLowerCase()) ||
      (o.description || "").toLowerCase().includes(search.toLowerCase());
    return matchPlatform && matchSearch;
  });

  // Conflict detection: an option conflicts if another enabled option shares the same
  // top-level namespace AND the same leaf key (e.g. services.nginx.enable vs services.xserver.enable)
  const conflictSet = useMemo(() => {
    const conflicts = new Set();
    const enabledSet = new Set(form.enabled_options);
    const enabledParsed = form.enabled_options.map((n) => ({
      name: n,
      parts: n.split("."),
    }));

    for (const opt of filteredOptions) {
      if (enabledSet.has(opt.name)) continue; // skip already-enabled
      const parts = opt.name.split(".");
      if (parts.length < 2) continue;
      const leaf = parts[parts.length - 1];
      const ns = parts[0];
      // Conflict: enabled option shares same namespace root AND same leaf key
      const hasConflict = enabledParsed.some((e) => {
        if (e.parts.length < 2) return false;
        const eLeaf = e.parts[e.parts.length - 1];
        const eNs = e.parts[0];
        return eLeaf === leaf && eNs === ns && e.name !== opt.name;
      });
      if (hasConflict) conflicts.add(opt.name);
    }
    return conflicts;
  }, [form.enabled_options, filteredOptions]);

  if (!open) return null;

  const toggleOption = (optName) => {
    setForm((f) => {
      const has = f.enabled_options.includes(optName);
      return {
        ...f,
        enabled_options: has
          ? f.enabled_options.filter((o) => o !== optName)
          : [...f.enabled_options, optName],
      };
    });
  };

  const toggleSelected = (optName) => {
    setSelected((s) => {
      const next = new Set(s);
      next.has(optName) ? next.delete(optName) : next.add(optName);
      return next;
    });
  };

  const allVisibleSelected =
    filteredOptions.length > 0 &&
    filteredOptions.every((o) => selected.has(o.name));
  const toggleSelectAll = () => {
    if (allVisibleSelected) {
      setSelected((s) => {
        const n = new Set(s);
        filteredOptions.forEach((o) => n.delete(o.name));
        return n;
      });
    } else {
      setSelected((s) => {
        const n = new Set(s);
        filteredOptions.forEach((o) => n.add(o.name));
        return n;
      });
    }
  };

  const enableSelected = () => {
    setForm((f) => ({
      ...f,
      enabled_options: [...new Set([...f.enabled_options, ...selected])],
    }));
    setSelected(new Set());
  };

  const disableSelected = () => {
    setForm((f) => ({
      ...f,
      enabled_options: f.enabled_options.filter((o) => !selected.has(o)),
    }));
    setSelected(new Set());
  };

  const applyTemplate = (tpl) => {
    setForm((f) => ({
      ...f,
      enabled_options: [...new Set([...f.enabled_options, ...tpl.options])],
    }));
    setShowTemplates(false);
  };

  const handleSave = () => {
    const data = {
      ...form,
      tags: form.tags
        ? form.tags
            .split(",")
            .map((t) => t.trim())
            .filter(Boolean)
        : [],
    };
    if (profile) saveProfileVersion({ ...profile, ...data });
    onSave(data);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50">
      <div className="bg-card border border-border w-full max-w-2xl shadow-xl flex flex-col max-h-[90vh]">
        <div className="flex items-center justify-between px-5 py-4 border-b border-border shrink-0">
          <h2 className="font-mono text-sm font-semibold">
            {profile ? "edit profile" : "new profile"}
          </h2>
          <button
            onClick={onClose}
            className="text-muted-foreground hover:text-foreground"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Tabs */}
        <div className="flex border-b border-border shrink-0">
          {["general", "options", "dependencies", "history"].map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className={`px-4 py-2.5 text-xs font-mono font-medium transition-colors border-b-2 -mb-px ${tab === t ? "border-copper text-copper" : "border-transparent text-muted-foreground hover:text-foreground"}`}
            >
              {t}
              {t === "options" && form.enabled_options.length > 0 && (
                <span className="ml-1.5 bg-copper-subtle text-copper px-1">
                  {form.enabled_options.length}
                </span>
              )}
            </button>
          ))}
          <div className="ml-auto flex items-center pr-3">
            <button
              onClick={() => setExportOpen(true)}
              className="flex items-center gap-1.5 text-xs font-mono text-muted-foreground hover:text-foreground border border-border px-2 py-1 transition-colors"
            >
              <Code className="w-3 h-3" /> export nix
            </button>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto">
          {tab === "general" && (
            <div className="p-5 space-y-4">
              <Field label="name" required>
                <input
                  value={form.name}
                  onChange={(e) => set("name", e.target.value)}
                  className="w-full border border-border px-3 py-2 font-mono text-sm focus:outline-hidden focus:border-copper"
                  placeholder="workstation"
                />
              </Field>
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
              <Field label="description">
                <textarea
                  value={form.description}
                  onChange={(e) => set("description", e.target.value)}
                  rows={2}
                  className="w-full border border-border px-3 py-2 text-sm focus:outline-hidden focus:border-copper resize-none"
                  placeholder="What is this profile for?"
                />
              </Field>
              <Field label="tags (comma-separated)">
                <input
                  value={form.tags}
                  onChange={(e) => set("tags", e.target.value)}
                  className="w-full border border-border px-3 py-2 font-mono text-sm focus:outline-hidden focus:border-copper"
                  placeholder="work, desktop, full"
                />
              </Field>
            </div>
          )}

          {tab === "options" && (
            <div>
              <div className="px-5 py-3 border-b border-border sticky top-0 bg-card z-10 space-y-2">
                {/* Template actions row */}
                <div className="flex items-center gap-2 pb-1">
                  <div className="relative">
                    <button
                      onClick={() => setShowTemplates((t) => !t)}
                      className="flex items-center gap-1 text-xs font-mono text-muted-foreground hover:text-foreground border border-border px-2 py-1 transition-colors"
                    >
                      <Layers className="w-3 h-3" />
                      apply template
                      <ChevronDown className="w-3 h-3" />
                    </button>
                    {showTemplates && (
                      <div className="absolute left-0 top-full mt-1 bg-card border border-border shadow-lg z-20 min-w-[200px]">
                        {templates.length === 0 ? (
                          <div className="px-3 py-2 text-xs text-muted-foreground font-mono">
                            no templates saved yet
                          </div>
                        ) : (
                          templates.map((tpl) => (
                            <button
                              key={tpl.id}
                              onClick={() => applyTemplate(tpl)}
                              className="w-full text-left px-3 py-2 text-xs hover:bg-muted/50 transition-colors"
                            >
                              <div className="font-mono font-medium text-foreground">
                                {tpl.name}
                              </div>
                              <div className="text-muted-foreground">
                                {tpl.options.length} options
                                {tpl.description ? ` · ${tpl.description}` : ""}
                              </div>
                            </button>
                          ))
                        )}
                      </div>
                    )}
                  </div>
                  {form.enabled_options.length > 0 && (
                    <button
                      onClick={() => setSaveTemplateOpen(true)}
                      className="flex items-center gap-1 text-xs font-mono text-muted-foreground hover:text-copper border border-border px-2 py-1 transition-colors"
                    >
                      <Layers className="w-3 h-3" />
                      save as template
                    </button>
                  )}
                </div>
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-muted-foreground" />
                  <input
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    placeholder="search options..."
                    className="w-full pl-8 pr-3 py-2 border border-border font-mono text-xs focus:outline-hidden focus:border-copper"
                  />
                </div>
                <div className="flex items-center justify-between gap-2">
                  <button
                    onClick={toggleSelectAll}
                    className="flex items-center gap-1.5 text-xs text-muted-foreground hover:text-foreground transition-colors font-mono"
                  >
                    {allVisibleSelected ? (
                      <CheckSquare className="w-3.5 h-3.5 text-copper" />
                    ) : (
                      <Square className="w-3.5 h-3.5" />
                    )}
                    {allVisibleSelected ? "deselect all" : "select all"}
                  </button>
                  {selected.size > 0 && (
                    <div className="flex items-center gap-2">
                      <span className="font-mono text-xs text-copper">
                        {selected.size} selected
                      </span>
                      <button
                        onClick={enableSelected}
                        className="flex items-center gap-1 px-2 py-1 text-xs bg-primary text-primary-foreground hover:bg-copper-hover transition-colors"
                      >
                        <ToggleRight className="w-3 h-3" /> enable
                      </button>
                      <button
                        onClick={disableSelected}
                        className="flex items-center gap-1 px-2 py-1 text-xs border border-border text-muted-foreground hover:text-foreground transition-colors"
                      >
                        <ToggleLeft className="w-3 h-3" /> disable
                      </button>
                    </div>
                  )}
                  {selected.size === 0 && (
                    <p className="text-xs text-muted-foreground">
                      {filteredOptions.length} options for{" "}
                      <span className="font-mono">{form.platform}</span>
                    </p>
                  )}
                </div>
              </div>
              {filteredOptions.length === 0 ? (
                <div className="p-8 text-center text-xs text-muted-foreground font-mono">
                  {options.length === 0
                    ? "No options in database yet. Seed some from the Packages page."
                    : "No matching options."}
                </div>
              ) : (
                <div className="divide-y divide-border">
                  {filteredOptions.map((opt) => {
                    const enabled = form.enabled_options.includes(opt.name);
                    const isSel = selected.has(opt.name);
                    const isConflict = !enabled && conflictSet.has(opt.name);
                    return (
                      <div
                        key={opt.id}
                        className={`flex items-start gap-3 px-5 py-3 transition-colors ${
                          isSel
                            ? "bg-copper-subtle"
                            : enabled
                              ? "bg-copper-subtle"
                              : isConflict
                                ? "bg-destructive/10 opacity-50"
                                : "hover:bg-muted/30"
                        }`}
                      >
                        {/* selection checkbox */}
                        <button
                          onClick={() => toggleSelected(opt.name)}
                          className={`w-4 h-4 border flex items-center justify-center shrink-0 mt-0.5 transition-colors ${isSel ? "bg-copper-subtle border-copper" : "border-border hover:border-copper"}`}
                        >
                          {isSel && <Check className="w-3 h-3 text-copper" />}
                        </button>
                        {/* enabled toggle */}
                        <button
                          onClick={() => toggleOption(opt.name)}
                          className={`w-4 h-4 border flex items-center justify-center shrink-0 mt-0.5 transition-colors ${enabled ? "bg-primary border-copper" : isConflict ? "border-destructive" : "border-border hover:border-copper"}`}
                        >
                          {enabled && <Check className="w-3 h-3 text-white" />}
                        </button>
                        <div
                          className="min-w-0 flex-1 cursor-pointer"
                          onClick={() => toggleOption(opt.name)}
                        >
                          <div
                            className={`font-mono text-xs font-medium ${isConflict ? "line-through text-muted-foreground" : "text-foreground"}`}
                          >
                            {opt.name}
                            {isConflict && (
                              <span className="ml-2 no-underline font-normal text-destructive font-mono text-xs">
                                [conflict]
                              </span>
                            )}
                          </div>
                          {opt.description && (
                            <div className="text-xs text-muted-foreground mt-0.5 line-clamp-2">
                              {opt.description}
                            </div>
                          )}
                          <div className="flex items-center gap-2 mt-1">
                            {opt.option_type && (
                              <span className="font-mono text-xs text-copper">
                                {opt.option_type}
                              </span>
                            )}
                            {opt.default_value && (
                              <span className="font-mono text-xs text-muted-foreground">
                                default: {opt.default_value}
                              </span>
                            )}
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}
          {tab === "dependencies" && (
            <div className="p-4">
              <p className="text-xs text-muted-foreground mb-3 font-mono">
                Visual map of how enabled options relate by namespace. Options
                in the same namespace share an edge.
              </p>
              <OptionDependencyGraph
                enabledOptions={form.enabled_options}
                allOptions={options}
              />
            </div>
          )}

          {tab === "history" && (
            <ProfileVersionHistory
              profile={profile}
              onRevert={(snapshot) => {
                setForm({
                  name: snapshot.name || "",
                  platform: snapshot.platform || "nixos",
                  description: snapshot.description || "",
                  tags: (snapshot.tags || []).join(", "),
                  options: snapshot.options || {},
                  enabled_options: snapshot.enabled_options || [],
                });
                setTab("general");
              }}
            />
          )}
        </div>

        <div className="px-5 py-4 border-t border-border flex justify-end gap-2 shrink-0">
          <button
            onClick={onClose}
            className="px-4 py-2 text-xs border border-border text-muted-foreground hover:text-foreground transition-colors"
          >
            cancel
          </button>
          <button
            onClick={handleSave}
            disabled={!form.name}
            className="px-4 py-2 text-xs bg-foreground text-background hover:bg-copper-hover transition-colors disabled:opacity-40"
          >
            {profile ? "save changes" : "create profile"}
          </button>
        </div>
      </div>
      <NixExportModal
        open={exportOpen}
        onClose={() => setExportOpen(false)}
        profile={{
          ...form,
          tags: form.tags
            ? form.tags
                .split(",")
                .map((t) => t.trim())
                .filter(Boolean)
            : [],
        }}
        options={options}
      />
      <SaveTemplateModal
        open={saveTemplateOpen}
        onClose={() => setSaveTemplateOpen(false)}
        options={form.enabled_options}
        platform={form.platform}
        onSaved={() =>
          api.entities.OptionTemplate.list()
            .then(setTemplates)
            .catch(() => {})
        }
      />
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

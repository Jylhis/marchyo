import { useState, useEffect } from "react";
import { api } from "@/api/client";
import { LayoutGrid, Plus, ChevronRight } from "lucide-react";
import PageHeader from "@/components/PageHeader";
import PlatformBadge from "@/components/PlatformBadge";
import EmptyState from "@/components/EmptyState";
import ProfileModal from "@/components/ProfileModal";
import { formatDistanceToNow } from "date-fns";

export default function Profiles() {
  const [profiles, setProfiles] = useState([]);
  const [options, setOptions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState(null);

  const load = async () => {
    const [p, o] = await Promise.all([
      api.entities.ConfigProfile.list("-created_date"),
      api.entities.MarchyoOption.list(),
    ]);
    setProfiles(p);
    setOptions(o);
    setLoading(false);
  };

  useEffect(() => {
    load();
  }, []);

  const handleSave = async (data) => {
    if (editing) {
      await api.entities.ConfigProfile.update(editing.id, data);
    } else {
      await api.entities.ConfigProfile.create(data);
    }
    setModalOpen(false);
    setEditing(null);
    load();
  };

  const handleDelete = async (id) => {
    await api.entities.ConfigProfile.delete(id);
    load();
  };

  const openEdit = (p) => {
    setEditing(p);
    setModalOpen(true);
  };
  const openNew = () => {
    setEditing(null);
    setModalOpen(true);
  };

  return (
    <div className="animate-fade-in">
      <PageHeader
        title="config profiles"
        subtitle="Reusable configuration sets for your machines"
        actions={
          <button
            onClick={openNew}
            className="flex items-center gap-2 px-3 py-1.5 bg-primary text-primary-foreground text-xs font-mono font-medium hover:bg-copper-hover transition-colors"
          >
            <Plus className="w-3.5 h-3.5" /> new profile
          </button>
        }
      />

      {loading ? (
        <div className="p-8 grid md:grid-cols-2 lg:grid-cols-3 gap-4">
          {[1, 2, 3].map((i) => (
            <div key={i} className="h-32 bg-muted animate-pulse" />
          ))}
        </div>
      ) : profiles.length === 0 ? (
        <EmptyState
          icon={LayoutGrid}
          title="No config profiles yet"
          description="Create a profile to define a set of Marchyo options for a platform target."
          action={
            <button
              onClick={openNew}
              className="px-4 py-2 text-xs font-mono font-medium bg-primary text-primary-foreground hover:bg-copper-hover transition-colors"
            >
              new profile
            </button>
          }
        />
      ) : (
        <div className="divide-y divide-border border-t border-border">
          {profiles.map((profile) => {
            const optCount = profile.enabled_options?.length || 0;
            const optKeys = Object.keys(profile.options || {}).length;
            return (
              <div
                key={profile.id}
                className="group flex items-start justify-between gap-4 px-6 py-4 hover:bg-canvas-subtle transition-colors"
              >
                <div className="min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    <span className="font-mono text-sm font-semibold text-ink-heading">
                      {profile.name}
                    </span>
                    <PlatformBadge platform={profile.platform} />
                  </div>
                  {profile.description && (
                    <p className="text-sm text-ink-muted mb-2 max-w-2xl text-pretty">
                      {profile.description}
                    </p>
                  )}
                  {profile.tags?.length > 0 && (
                    <div className="flex flex-wrap gap-1">
                      {profile.tags.map((t) => (
                        <span
                          key={t}
                          className="font-mono text-xs px-1.5 py-0.5 bg-muted text-ink-muted"
                        >
                          {t}
                        </span>
                      ))}
                    </div>
                  )}
                </div>
                <div className="flex flex-col items-end gap-1.5 shrink-0 text-right">
                  <span className="font-mono text-xs text-ink-muted">
                    {optCount + optKeys} options
                  </span>
                  <span className="text-xs text-ink-faint">
                    {formatDistanceToNow(
                      new Date(profile.updated_date || profile.created_date),
                      { addSuffix: true },
                    )}
                  </span>
                  <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button
                      onClick={() => openEdit(profile)}
                      className="font-mono text-xs text-ink-muted hover:text-copper border border-border px-2 py-1"
                    >
                      edit
                    </button>
                    <button
                      onClick={() => handleDelete(profile.id)}
                      className="font-mono text-xs text-destructive hover:opacity-80 border border-border px-2 py-1"
                    >
                      delete
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      <ProfileModal
        open={modalOpen}
        onClose={() => {
          setModalOpen(false);
          setEditing(null);
        }}
        onSave={handleSave}
        profile={editing}
        options={options}
      />
    </div>
  );
}

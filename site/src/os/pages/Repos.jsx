import { useState, useEffect } from "react";
import { api } from "@/api/client";
import { GitBranch, Plus, ExternalLink, RefreshCw } from "lucide-react";
import PageHeader from "@/components/PageHeader";
import StatusBadge from "@/components/StatusBadge";
import EmptyState from "@/components/EmptyState";
import RepoModal from "@/components/RepoModal";
import { formatDistanceToNow } from "date-fns";

export default function Repos() {
  const [repos, setRepos] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState(null);

  const load = async () => {
    const r = await api.entities.GitRepo.list("-created_date");
    setRepos(r);
    setLoading(false);
  };

  useEffect(() => {
    load();
  }, []);

  const handleSave = async (data) => {
    if (editing) {
      await api.entities.GitRepo.update(editing.id, data);
    } else {
      await api.entities.GitRepo.create({ ...data, status: "pending" });
    }
    setModalOpen(false);
    setEditing(null);
    load();
  };

  const handleDelete = async (id) => {
    await api.entities.GitRepo.delete(id);
    load();
  };

  const openEdit = (r) => {
    setEditing(r);
    setModalOpen(true);
  };
  const openNew = () => {
    setEditing(null);
    setModalOpen(true);
  };

  return (
    <div className="animate-fade-in">
      <PageHeader
        title="git repos"
        subtitle="Connect your Nix flake repos as config sources of truth"
        actions={
          <button
            onClick={openNew}
            className="flex items-center gap-2 px-3 py-1.5 bg-primary text-primary-foreground text-xs font-medium hover:bg-copper-hover transition-colors"
          >
            <Plus className="w-3.5 h-3.5" /> Connect repo
          </button>
        }
      />

      {loading ? (
        <div className="p-8 space-y-3">
          {[1, 2].map((i) => (
            <div key={i} className="h-20 bg-muted animate-pulse" />
          ))}
        </div>
      ) : repos.length === 0 ? (
        <EmptyState
          icon={GitBranch}
          title="No repos connected"
          description="Connect your Nix flake repo to track config state and enable remote builds."
          action={
            <button
              onClick={openNew}
              className="px-4 py-2 text-xs font-medium bg-primary text-primary-foreground hover:bg-copper-hover transition-colors"
            >
              Connect repo
            </button>
          }
        />
      ) : (
        <div className="divide-y divide-border">
          {repos.map((repo) => {
            const repoName =
              repo.name ||
              repo.url.replace(/^https?:\/\//, "").replace(/\.git$/, "");
            return (
              <div
                key={repo.id}
                className="px-6 py-4 hover:bg-muted/30 transition-colors group"
              >
                <div className="flex items-start justify-between gap-4">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2.5 mb-1">
                      <GitBranch className="w-3.5 h-3.5 text-muted-foreground shrink-0" />
                      <span className="font-mono text-sm font-medium text-foreground truncate">
                        {repoName}
                      </span>
                      <StatusBadge status={repo.status || "pending"} />
                    </div>
                    <div className="font-mono text-xs text-muted-foreground mb-1.5 truncate">
                      {repo.url}
                    </div>
                    <div className="flex items-center gap-4 text-xs text-muted-foreground">
                      <span className="font-mono flex items-center gap-1">
                        <span className="text-ink-faint">@</span>
                        {repo.branch || "main"}
                      </span>
                      {repo.last_sync && (
                        <span className="flex items-center gap-1">
                          <RefreshCw className="w-3 h-3" />
                          synced{" "}
                          {formatDistanceToNow(new Date(repo.last_sync), {
                            addSuffix: true,
                          })}
                        </span>
                      )}
                      {repo.error_message && (
                        <span className="text-status-err font-mono">
                          {repo.error_message}
                        </span>
                      )}
                    </div>
                  </div>
                  <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity shrink-0">
                    <a
                      href={repo.url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="p-1.5 border border-border text-muted-foreground hover:text-foreground transition-colors"
                    >
                      <ExternalLink className="w-3.5 h-3.5" />
                    </a>
                    <button
                      onClick={() => openEdit(repo)}
                      className="text-xs border border-border px-2 py-1 text-muted-foreground hover:text-foreground transition-colors"
                    >
                      edit
                    </button>
                    <button
                      onClick={() => handleDelete(repo.id)}
                      className="text-xs border border-border px-2 py-1 text-destructive hover:opacity-80 transition-colors"
                    >
                      remove
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      <RepoModal
        open={modalOpen}
        onClose={() => {
          setModalOpen(false);
          setEditing(null);
        }}
        onSave={handleSave}
        repo={editing}
      />
    </div>
  );
}

import { useState, useEffect, useMemo } from "react";
import { api } from "@/api/client";
import { Server, Plus, Clock, GitBranch, Tag, X } from "lucide-react";
import PageHeader from "@/components/PageHeader";
import StatusBadge from "@/components/StatusBadge";
import PlatformBadge from "@/components/PlatformBadge";
import EmptyState from "@/components/EmptyState";
import MachineModal from "@/components/MachineModal";
import MachineInstructions from "@/components/MachineInstructions";
import FleetCharts from "@/components/FleetCharts";
import MachineDetailDrawer from "@/components/MachineDetailDrawer";
import { formatDistanceToNow } from "date-fns";

export default function Fleet() {
  const [machines, setMachines] = useState([]);
  const [profiles, setProfiles] = useState([]);
  const [repos, setRepos] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState(null);
  const [activeTag, setActiveTag] = useState(null);
  const [drawerMachine, setDrawerMachine] = useState(null);

  const load = async () => {
    const [m, p, r] = await Promise.all([
      api.entities.Machine.list("-created_date"),
      api.entities.ConfigProfile.list(),
      api.entities.GitRepo.list(),
    ]);
    setMachines(m);
    setProfiles(p);
    setRepos(r);
    setLoading(false);
  };

  useEffect(() => {
    load();
  }, []);

  const profileMap = Object.fromEntries(profiles.map((p) => [p.id, p]));
  const repoMap = Object.fromEntries(repos.map((r) => [r.id, r]));

  // Collect all unique tags across machines
  const allTags = useMemo(() => {
    const set = new Set();
    machines.forEach((m) => (m.tags || []).forEach((t) => set.add(t)));
    return [...set].sort();
  }, [machines]);

  const filteredMachines = useMemo(
    () =>
      activeTag
        ? machines.filter((m) => (m.tags || []).includes(activeTag))
        : machines,
    [machines, activeTag],
  );

  const handleSave = async (data) => {
    if (editing) {
      await api.entities.Machine.update(editing.id, data);
    } else {
      await api.entities.Machine.create(data);
    }
    setModalOpen(false);
    setEditing(null);
    load();
  };

  const handleDelete = async (id) => {
    await api.entities.Machine.delete(id);
    load();
  };

  const openEdit = (machine) => {
    setEditing(machine);
    setModalOpen(true);
  };
  const openNew = () => {
    setEditing(null);
    setModalOpen(true);
  };
  const openDrawer = (machine) => setDrawerMachine(machine);

  const counts = {
    total: machines.length,
    online: machines.filter((m) => m.status === "online").length,
    stale: machines.filter((m) => m.status === "stale").length,
  };

  return (
    <div className="animate-fade-in">
      <PageHeader
        title="fleet"
        subtitle={`${counts.total} machines · ${counts.online} online · ${counts.stale} stale`}
        actions={
          <button
            onClick={openNew}
            className="flex items-center gap-2 px-3 py-1.5 bg-primary text-primary-foreground text-xs font-medium hover:bg-copper-hover transition-colors"
          >
            <Plus className="w-3.5 h-3.5" /> Add machine
          </button>
        }
      />

      {/* Tag filter bar */}
      {allTags.length > 0 && (
        <div className="flex items-center gap-2 px-6 py-3 border-b border-border overflow-x-auto">
          <Tag className="w-3 h-3 text-muted-foreground shrink-0" />
          <button
            onClick={() => setActiveTag(null)}
            className={`font-mono text-xs px-2 py-0.5 transition-colors shrink-0 ${!activeTag ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:text-foreground border border-border"}`}
          >
            all
          </button>
          {allTags.map((tag) => (
            <button
              key={tag}
              onClick={() => setActiveTag(activeTag === tag ? null : tag)}
              className={`font-mono text-xs px-2 py-0.5 transition-colors shrink-0 ${activeTag === tag ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:text-copper border border-border hover:border-copper"}`}
            >
              {tag}
            </button>
          ))}
          {activeTag && (
            <button
              onClick={() => setActiveTag(null)}
              className="ml-auto shrink-0 text-muted-foreground hover:text-foreground"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          )}
        </div>
      )}

      {!loading && machines.length > 0 && <FleetCharts machines={machines} />}

      {loading ? (
        <div className="p-8 space-y-2">
          {[1, 2, 3].map((i) => (
            <div key={i} className="h-16 bg-muted animate-pulse" />
          ))}
        </div>
      ) : machines.length === 0 ? (
        <>
          <EmptyState
            icon={Server}
            title="No machines registered"
            description="Add your first machine to start tracking your fleet."
            action={
              <button
                onClick={openNew}
                className="px-4 py-2 text-xs font-medium bg-primary text-primary-foreground hover:bg-copper-hover transition-colors"
              >
                Add machine
              </button>
            }
          />
          <MachineInstructions collapsed={false} />
        </>
      ) : (
        <>
          <MachineInstructions collapsed={true} />
          <div className="overflow-x-auto">
            <table className="w-full text-xs border-collapse">
              <thead>
                <tr className="border-b border-border bg-muted/50">
                  <th className="px-6 py-3 text-left font-mono font-medium text-muted-foreground">
                    hostname
                  </th>
                  <th className="px-4 py-3 text-left font-mono font-medium text-muted-foreground">
                    platform
                  </th>
                  <th className="px-4 py-3 text-left font-mono font-medium text-muted-foreground">
                    tags
                  </th>
                  <th className="px-4 py-3 text-left font-mono font-medium text-muted-foreground">
                    profile
                  </th>
                  <th className="px-4 py-3 text-left font-mono font-medium text-muted-foreground">
                    repo
                  </th>
                  <th className="px-4 py-3 text-left font-mono font-medium text-muted-foreground">
                    status
                  </th>
                  <th className="px-4 py-3 text-left font-mono font-medium text-muted-foreground">
                    last seen
                  </th>
                  <th className="px-4 py-3" />
                </tr>
              </thead>
              <tbody>
                {filteredMachines.map((machine) => {
                  const profile = profileMap[machine.profile_id];
                  const repo = repoMap[machine.git_repo_id];
                  return (
                    <tr
                      key={machine.id}
                      onClick={() => openDrawer(machine)}
                      className="border-b border-border hover:bg-muted/30 transition-colors group cursor-pointer"
                    >
                      <td className="px-6 py-3.5 font-mono font-medium text-foreground">
                        {machine.hostname}
                        {machine.arch && (
                          <span className="ml-2 text-muted-foreground">
                            ({machine.arch})
                          </span>
                        )}
                        {machine.description && (
                          <div className="text-muted-foreground font-normal text-xs">
                            {machine.description}
                          </div>
                        )}
                      </td>
                      <td className="px-4 py-3.5">
                        <PlatformBadge platform={machine.platform} />
                      </td>
                      <td className="px-4 py-3.5">
                        <div className="flex flex-wrap gap-1">
                          {(machine.tags || []).map((tag) => (
                            <button
                              key={tag}
                              onClick={(e) => {
                                e.stopPropagation();
                                setActiveTag(activeTag === tag ? null : tag);
                              }}
                              className={`font-mono text-xs px-1.5 py-0.5 transition-colors ${activeTag === tag ? "bg-primary text-primary-foreground" : "bg-copper-subtle text-copper hover:bg-copper-hover"}`}
                            >
                              {tag}
                            </button>
                          ))}
                          {(!machine.tags || machine.tags.length === 0) && (
                            <span className="text-muted-foreground italic">
                              —
                            </span>
                          )}
                        </div>
                      </td>
                      <td className="px-4 py-3.5 text-muted-foreground">
                        {profile ? (
                          <span className="font-mono">{profile.name}</span>
                        ) : (
                          <span className="italic">—</span>
                        )}
                      </td>
                      <td className="px-4 py-3.5 text-muted-foreground">
                        {repo ? (
                          <span className="font-mono flex items-center gap-1">
                            <GitBranch className="w-3 h-3" />
                            {repo.name || repo.url.split("/").pop()}
                          </span>
                        ) : (
                          <span className="italic">—</span>
                        )}
                      </td>
                      <td className="px-4 py-3.5">
                        <StatusBadge status={machine.status || "unknown"} />
                      </td>
                      <td className="px-4 py-3.5 text-muted-foreground flex items-center gap-1">
                        <Clock className="w-3 h-3 shrink-0" />
                        {machine.last_seen
                          ? formatDistanceToNow(new Date(machine.last_seen), {
                              addSuffix: true,
                            })
                          : "—"}
                      </td>
                      <td
                        className="px-4 py-3.5 text-right"
                        onClick={(e) => e.stopPropagation()}
                      >
                        <div className="flex items-center gap-2 justify-end opacity-0 group-hover:opacity-100 transition-opacity">
                          <button
                            onClick={() => openEdit(machine)}
                            className="text-muted-foreground hover:text-foreground transition-colors px-2 py-1 border border-border"
                          >
                            edit
                          </button>
                          <button
                            onClick={() => handleDelete(machine.id)}
                            className="text-destructive hover:opacity-80 transition-colors px-2 py-1 border border-border"
                          >
                            delete
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
            {filteredMachines.length === 0 && activeTag && (
              <div className="p-8 text-center text-xs text-muted-foreground font-mono">
                No machines tagged{" "}
                <span className="text-copper">"{activeTag}"</span>.{" "}
                <button
                  onClick={() => setActiveTag(null)}
                  className="underline"
                >
                  show all
                </button>
              </div>
            )}
          </div>
        </>
      )}

      <MachineDetailDrawer
        machine={drawerMachine}
        profile={drawerMachine ? profileMap[drawerMachine.profile_id] : null}
        repo={drawerMachine ? repoMap[drawerMachine.git_repo_id] : null}
        onClose={() => setDrawerMachine(null)}
        onEdit={() => {
          openEdit(drawerMachine);
          setDrawerMachine(null);
        }}
      />
      <MachineModal
        open={modalOpen}
        onClose={() => {
          setModalOpen(false);
          setEditing(null);
        }}
        onSave={handleSave}
        machine={editing}
        profiles={profiles}
        repos={repos}
      />
    </div>
  );
}

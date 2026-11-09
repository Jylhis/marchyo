import { Outlet, Link, useLocation } from "react-router-dom";
import { useState } from "react";
import {
  LayoutGrid,
  Server,
  Settings,
  BookOpen,
  GitBranch,
  Menu,
  X,
} from "lucide-react";
import ThemeToggle from "@/components/ThemeToggle";

const NAV = [
  { label: "fleet", path: "/fleet", icon: Server },
  { label: "profiles", path: "/profiles", icon: LayoutGrid },
  { label: "repos", path: "/repos", icon: GitBranch },
  { label: "settings", path: "/settings", icon: Settings },
];

export default function Layout() {
  const location = useLocation();
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <div className="min-h-screen bg-background flex">
      {/* Sidebar */}
      <aside
        className={`
        fixed inset-y-0 left-0 z-40 w-56 bg-canvas-subtle border-r border-border flex flex-col
        transform transition-transform duration-200
        ${mobileOpen ? "translate-x-0" : "-translate-x-full"}
        lg:translate-x-0 lg:static lg:flex
      `}
      >
        {/* Logo */}
        <div className="h-14 flex items-center px-5 border-b border-border gap-0">
          <span className="font-mono font-semibold text-base text-ink-heading tracking-tight">
            marchyo
          </span>
          <span className="font-mono text-base text-copper leading-none animate-blink">
            _
          </span>
        </div>

        {/* Nav */}
        <nav className="flex-1 py-4 px-2 space-y-0.5">
          {NAV.map(({ label, path, icon: Icon }) => {
            const active = location.pathname.startsWith(path);
            return (
              <Link
                key={path}
                to={path}
                onClick={() => setMobileOpen(false)}
                aria-current={active ? "page" : undefined}
                className={`
                  flex items-center gap-2.5 px-3 py-2 font-mono text-sm transition-colors
                  focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-ring
                  focus-visible:ring-inset
                  ${
                    active
                      ? "bg-copper-subtle text-copper font-medium border-l-2 border-copper -ml-px pl-[11px]"
                      : "text-ink-muted hover:text-ink hover:bg-canvas"
                  }
                `}
              >
                <Icon className="w-4 h-4 shrink-0" />
                {label}
              </Link>
            );
          })}
        </nav>

        {/* Footer */}
        <div className="border-t border-border p-3 flex items-center justify-between">
          <Link
            to="/"
            className="flex items-center gap-2 px-3 py-2 font-mono text-xs text-ink-muted
              hover:text-ink transition-colors focus-visible:outline-hidden
              focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-inset"
          >
            <BookOpen className="w-3.5 h-3.5" />
            back to landing
          </Link>
          <ThemeToggle />
        </div>
      </aside>

      {/* Mobile overlay */}
      {mobileOpen && (
        <div
          className="fixed inset-0 z-30 bg-black/40 lg:hidden"
          onClick={() => setMobileOpen(false)}
        />
      )}

      {/* Main */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Top bar (mobile) */}
        <header className="h-14 border-b border-border bg-canvas-subtle flex items-center px-4 gap-3 lg:hidden">
          <button
            onClick={() => setMobileOpen(true)}
            aria-label="Open navigation"
            className="p-1 text-ink-muted hover:text-ink"
          >
            <Menu className="w-5 h-5" />
          </button>
          <span className="font-mono font-semibold text-sm text-ink-heading">
            marchyo<span className="text-copper">_</span>
          </span>
          <ThemeToggle className="ml-auto" />
        </header>

        <main className="flex-1 overflow-auto">
          <Outlet />
        </main>
      </div>
    </div>
  );
}

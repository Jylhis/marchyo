import { Link, useLocation } from "react-router-dom";

export default function PageNotFound() {
  const location = useLocation();
  const pageName = location.pathname.substring(1) || location.pathname;

  return (
    <div className="min-h-screen flex items-center justify-center p-6 bg-background">
      <div className="max-w-lg w-full">
        <div className="terminal-block overflow-x-auto">
          <div className="flex items-center gap-2 px-4 py-2.5 border-b border-border">
            <span className="w-2 h-2 bg-status-err" aria-hidden />
            <span className="w-2 h-2 bg-status-warn" aria-hidden />
            <span className="w-2 h-2 bg-status-ok" aria-hidden />
            <span className="ml-2 text-ink-faint text-xs font-mono">
              marchyo-cli
            </span>
          </div>
          <div className="p-5 space-y-1 font-mono text-xs leading-6">
            <div>
              <span className="text-copper">❯ </span>
              <span className="text-ink">marchyo open /{pageName}</span>
            </div>
            <div className="text-status-err">error: no such route — 404</div>
            <div className="text-ink-muted">
              the page "/{pageName}" is not part of this app.
            </div>
          </div>
        </div>

        <div className="mt-6">
          <Link
            to="/"
            className="inline-flex items-center gap-2 px-4 py-2 font-mono text-sm font-medium text-ink border border-border hover:border-copper hover:text-copper transition-colors focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background"
          >
            <span className="text-decorator">›</span> back to landing
          </Link>
        </div>
      </div>
    </div>
  );
}

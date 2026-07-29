/**
 * marchyo-site Worker.
 *
 * This is an assets + script Worker (see wrangler.jsonc): static assets from
 * `dist` are served first, and only paths matched by `run_worker_first`
 * (`/api/*`) reach this script. Everything else falls back to the assets
 * binding.
 *
 * The single dynamic route, `/api/packages`, backs the "nixpkgs" tab of the
 * search page (site/src/pages/search.astro). It runs a SQLite FTS5 query
 * against the `marchyo-nixpkgs` D1 database, which is (re)built and loaded by
 * .github/workflows/nixpkgs-index.yml from marchyo's pinned nixpkgs rev.
 *
 * marchyo's own options and packages are searched entirely client-side from
 * committed JSON (site/src/data/*.json) and never touch this Worker.
 */

interface Env {
  ASSETS: Fetcher;
  DB?: D1Database;
}

interface PackageRow {
  attr_name: string;
  pname: string;
  version: string;
  description: string | null;
  homepage: string | null;
  license: string | null;
  main_program: string | null;
}

const MAX_RESULTS = 50;
const CACHE_SECONDS = 300;

function json(body: unknown, extraHeaders: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    headers: {
      "content-type": "application/json; charset=utf-8",
      ...extraHeaders,
    },
  });
}

/**
 * Turn free-form user input into a safe FTS5 MATCH expression. FTS5 treats a
 * bare double quote as a phrase delimiter and characters like `*`, `:`, `(`,
 * `-` as operators, so we tokenize on non-alphanumerics and build a quoted
 * prefix query: `"tok1"* "tok2"*`. Quotes inside a token are doubled to escape
 * them. Returns `null` when there is nothing searchable.
 */
function ftsQuery(raw: string): string | null {
  const tokens = raw
    .toLowerCase()
    .split(/[^a-z0-9.+_-]+/i)
    .map((t) => t.replace(/[-.]+$/g, "").replace(/^[-.]+/g, ""))
    .filter((t) => t.length > 0)
    .slice(0, 8);
  if (tokens.length === 0) return null;
  return tokens.map((t) => `"${t.replace(/"/g, '""')}"*`).join(" ");
}

async function handlePackages(url: URL, env: Env): Promise<Response> {
  const q = (url.searchParams.get("q") ?? "").trim();
  if (!q) return json({ query: q, results: [] });

  if (!env.DB) {
    return json(
      {
        query: q,
        results: [],
        error: "nixpkgs index unavailable (D1 binding not configured)",
      },
      { "cache-control": "no-store" },
    );
  }

  const match = ftsQuery(q);
  if (!match) return json({ query: q, results: [] });

  try {
    const { results } = await env.DB.prepare(
      `SELECT p.attr_name, p.pname, p.version, p.description, p.homepage, p.license, p.main_program
         FROM packages_fts f
         JOIN packages p ON p.rowid = f.rowid
        WHERE packages_fts MATCH ?1
        ORDER BY rank
        LIMIT ?2`,
    )
      .bind(match, MAX_RESULTS)
      .all<PackageRow>();

    return json(
      { query: q, results: results ?? [] },
      { "cache-control": `public, max-age=${CACHE_SECONDS}` },
    );
  } catch (e) {
    return json(
      { query: q, results: [], error: (e as Error).message },
      { "cache-control": "no-store" },
    );
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/api/packages") {
      if (request.method !== "GET") {
        return json({ error: "method not allowed" }, { allow: "GET" });
      }
      return handlePackages(url, env);
    }

    // Any other /api/* path is unknown; everything else defers to assets.
    if (url.pathname.startsWith("/api/")) {
      return json({ error: "not found" });
    }

    return env.ASSETS.fetch(request);
  },
} satisfies ExportedHandler<Env>;

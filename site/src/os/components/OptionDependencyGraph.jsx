import { useMemo } from "react";
import { useTheme } from "@/lib/theme";
import { light, dark } from "@/lib/tokens";

// Derive edges from namespace prefix relationships (options sharing a namespace parent depend on each other)
// and from known common Nix option dependency patterns
function buildGraph(enabledOptions, allOptions) {
  const optionMap = Object.fromEntries(
    (allOptions || []).map((o) => [o.name, o]),
  );
  const nodes = enabledOptions.map((name) => {
    const meta = optionMap[name] || {};
    const parts = name.split(".");
    return {
      id: name,
      label: parts.slice(-2).join("."),
      namespace: parts.slice(0, -1).join("."),
      category: meta.category || parts[0] || "misc",
    };
  });

  // Group by namespace — options in the same namespace share an edge
  const nsByOptions = {};
  nodes.forEach((n) => {
    if (!nsByOptions[n.namespace]) nsByOptions[n.namespace] = [];
    nsByOptions[n.namespace].push(n.id);
  });

  const edges = new Set();
  for (const [ns, ids] of Object.entries(nsByOptions)) {
    if (ids.length < 2) continue;
    for (let i = 0; i < ids.length - 1; i++) {
      edges.add(`${ids[i]}→${ids[i + 1]}`);
    }
  }

  return {
    nodes,
    edges: [...edges].map((e) => {
      const [s, t] = e.split("→");
      return { source: s, target: t };
    }),
  };
}

// Simple force-free layout: arrange by category in columns
function layout(nodes) {
  const categories = {};
  nodes.forEach((n) => {
    if (!categories[n.category]) categories[n.category] = [];
    categories[n.category].push(n);
  });

  const catList = Object.entries(categories);
  const MARGIN = 28;
  const NODE_W = 160;
  const NODE_H = 36;
  const COL_GAP = 60;
  const ROW_GAP = 18;

  const positioned = {};
  catList.forEach(([, ns], ci) => {
    ns.forEach((n, ri) => {
      positioned[n.id] = {
        x: MARGIN + ci * (NODE_W + COL_GAP),
        y: MARGIN + ri * (NODE_H + ROW_GAP),
      };
    });
  });

  const totalW = Math.max(
    400,
    MARGIN * 2 + catList.length * (NODE_W + COL_GAP),
  );
  const maxRows = Math.max(...catList.map(([, ns]) => ns.length), 1);
  const totalH = Math.max(200, MARGIN * 2 + maxRows * (NODE_H + ROW_GAP));

  return { positioned, totalW, totalH, NODE_W, NODE_H };
}

export default function OptionDependencyGraph({ enabledOptions, allOptions }) {
  const { theme } = useTheme();
  const pal = theme === "dark" ? dark : light;
  // Distinguishable but all drawn from the design palette — no arbitrary hues.
  const catColors = [
    pal.accent,
    pal.statusInfo,
    pal.statusOk,
    pal.brand,
    pal.statusWarn,
    pal.textMuted,
    pal.borderStrong,
  ];

  const { nodes, edges } = useMemo(
    () => buildGraph(enabledOptions, allOptions),
    [enabledOptions, allOptions],
  );
  const { positioned, totalW, totalH, NODE_W, NODE_H } = useMemo(
    () => layout(nodes),
    [nodes],
  );

  const categories = [...new Set(nodes.map((n) => n.category))];
  const catColorMap = Object.fromEntries(
    categories.map((cat, i) => [cat, catColors[i % catColors.length]]),
  );

  if (nodes.length === 0) {
    return (
      <div className="flex items-center justify-center h-40 text-xs text-ink-muted font-mono border border-border bg-canvas-subtle">
        enable options to see the dependency graph
      </div>
    );
  }

  return (
    <div className="border border-border bg-canvas-subtle overflow-auto">
      {/* Legend */}
      {categories.length > 1 && (
        <div className="flex flex-wrap gap-3 px-4 py-2.5 border-b border-border bg-card">
          {categories.map((cat) => (
            <div key={cat} className="flex items-center gap-1.5">
              <span
                className="w-2.5 h-2.5 inline-block"
                style={{ background: catColorMap[cat] }}
              />
              <span className="font-mono text-xs text-ink-muted">{cat}</span>
            </div>
          ))}
        </div>
      )}
      <svg width={totalW} height={totalH} className="block">
        <defs>
          <marker
            id="arrow"
            markerWidth="6"
            markerHeight="6"
            refX="5"
            refY="3"
            orient="auto"
          >
            <path d="M0,0 L6,3 L0,6 Z" fill={pal.border} />
          </marker>
        </defs>
        {/* Edges */}
        {edges.map((e, i) => {
          const s = positioned[e.source];
          const t = positioned[e.target];
          if (!s || !t) return null;
          const sx = s.x + NODE_W;
          const sy = s.y + NODE_H / 2;
          const tx = t.x;
          const ty = t.y + NODE_H / 2;
          const mx = (sx + tx) / 2;
          return (
            <path
              key={i}
              d={`M${sx},${sy} C${mx},${sy} ${mx},${ty} ${tx},${ty}`}
              fill="none"
              stroke={pal.border}
              strokeWidth="1.5"
              markerEnd="url(#arrow)"
            />
          );
        })}
        {/* Nodes — category shown as a top bar, not a side stripe */}
        {nodes.map((n) => {
          const pos = positioned[n.id];
          if (!pos) return null;
          const color = catColorMap[n.category] || pal.accent;
          return (
            <g key={n.id} transform={`translate(${pos.x},${pos.y})`}>
              <rect
                width={NODE_W}
                height={NODE_H}
                fill={pal.surfaceRaised}
                stroke={pal.border}
                strokeWidth="1"
              />
              <rect width={NODE_W} height="2" fill={color} />
              <text
                x="10"
                y="16"
                fontSize="9"
                fontFamily="JetBrains Mono, monospace"
                fill={pal.textMuted}
              >
                {n.namespace}
              </text>
              <text
                x="10"
                y="28"
                fontSize="10"
                fontFamily="JetBrains Mono, monospace"
                fontWeight="600"
                fill={pal.textHeading}
              >
                {n.label.length > 20 ? n.label.slice(0, 19) + "…" : n.label}
              </text>
            </g>
          );
        })}
      </svg>
    </div>
  );
}

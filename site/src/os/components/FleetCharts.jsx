import { useMemo } from "react";
import {
  PieChart,
  Pie,
  Cell,
  Tooltip,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  ResponsiveContainer,
  CartesianGrid,
} from "recharts";
import { useTheme } from "@/lib/theme";
import { light, dark } from "@/lib/tokens";

// Generate mock 24-hour activity data anchored to current time
function mockActivity(machines) {
  const total = machines.length || 3;
  const now = Date.now();
  return Array.from({ length: 24 }, (_, i) => {
    const h = new Date(now - (23 - i) * 3600 * 1000);
    const label = `${String(h.getHours()).padStart(2, "0")}:00`;
    const online = Math.max(
      1,
      Math.round(total * (0.6 + 0.35 * Math.sin(i / 4) + Math.random() * 0.1)),
    );
    const stale = Math.min(total - online, Math.floor(Math.random() * 2));
    return { label, online: Math.min(online, total), stale };
  });
}

export default function FleetCharts({ machines }) {
  const { theme } = useTheme();
  const c = theme === "dark" ? dark : light;
  const status = {
    online: c.accent,
    stale: c.statusWarn,
    unknown: c.textFaint,
  };
  const tooltipStyle = {
    background: c.bg,
    border: `1px solid ${c.border}`,
    borderRadius: 0,
    fontFamily: "monospace",
    fontSize: 11,
  };

  const donut = useMemo(() => {
    const online = machines.filter((m) => m.status === "online").length;
    const stale = machines.filter((m) => m.status === "stale").length;
    const unknown = machines.filter(
      (m) => !m.status || m.status === "unknown",
    ).length;
    return [
      { name: "online", value: online, color: c.accent },
      { name: "stale", value: stale, color: c.statusWarn },
      { name: "unknown", value: unknown, color: c.textFaint },
    ].filter((d) => d.value > 0);
  }, [machines, c.accent, c.statusWarn, c.textFaint]);

  const activity = useMemo(() => mockActivity(machines), [machines]);

  // Only show every 4th label to avoid crowding
  const tickFormatter = (val, idx) => (idx % 4 === 0 ? val : "");
  const axisTick = { fontFamily: "monospace", fontSize: 10, fill: c.textFaint };

  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-0 border-b border-border">
      {/* Status donut */}
      <div className="border-r border-border p-5 flex flex-col gap-3">
        <p className="font-mono text-xs text-ink-faint">status</p>
        <div className="flex items-center gap-4">
          <div style={{ width: 90, height: 90 }}>
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={
                    donut.length
                      ? donut
                      : [{ name: "none", value: 1, color: c.surface }]
                  }
                  cx="50%"
                  cy="50%"
                  innerRadius={28}
                  outerRadius={42}
                  dataKey="value"
                  strokeWidth={0}
                >
                  {(donut.length ? donut : [{ color: c.surface }]).map(
                    (entry, i) => (
                      <Cell key={i} fill={entry.color} />
                    ),
                  )}
                </Pie>
                <Tooltip
                  contentStyle={tooltipStyle}
                  itemStyle={{ color: c.text }}
                />
              </PieChart>
            </ResponsiveContainer>
          </div>
          <div className="space-y-1.5">
            {[
              {
                label: "online",
                color: status.online,
                count: machines.filter((m) => m.status === "online").length,
              },
              {
                label: "stale",
                color: status.stale,
                count: machines.filter((m) => m.status === "stale").length,
              },
              {
                label: "unknown",
                color: status.unknown,
                count: machines.filter(
                  (m) => !m.status || m.status === "unknown",
                ).length,
              },
            ].map(({ label, color, count }) => (
              <div
                key={label}
                className="flex items-center gap-2 text-xs font-mono"
              >
                <span
                  className="w-2.5 h-2.5 shrink-0"
                  style={{ background: color }}
                />
                <span className="text-ink-muted">{label}</span>
                <span className="ml-auto text-ink-heading font-medium">
                  {count}
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Activity over time — spans 2 cols */}
      <div className="md:col-span-2 p-5 flex flex-col gap-3">
        <p className="font-mono text-xs text-ink-faint">activity · last 24 h</p>
        <div style={{ height: 80 }}>
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart
              data={activity}
              margin={{ top: 2, right: 0, left: -32, bottom: 0 }}
            >
              <defs>
                <linearGradient id="online-fill" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor={c.accent} stopOpacity={0.25} />
                  <stop offset="95%" stopColor={c.accent} stopOpacity={0} />
                </linearGradient>
                <linearGradient id="stale-fill" x1="0" y1="0" x2="0" y2="1">
                  <stop
                    offset="5%"
                    stopColor={c.statusWarn}
                    stopOpacity={0.2}
                  />
                  <stop offset="95%" stopColor={c.statusWarn} stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid
                strokeDasharray="2 4"
                stroke={c.border}
                vertical={false}
              />
              <XAxis
                dataKey="label"
                tick={axisTick}
                tickLine={false}
                axisLine={false}
                tickFormatter={tickFormatter}
              />
              <YAxis
                allowDecimals={false}
                tick={axisTick}
                tickLine={false}
                axisLine={false}
              />
              <Tooltip
                contentStyle={tooltipStyle}
                itemStyle={{ color: c.text }}
                labelStyle={{ color: c.textMuted }}
              />
              <Area
                type="monotone"
                dataKey="online"
                name="online"
                stroke={c.accent}
                strokeWidth={1.5}
                fill="url(#online-fill)"
                dot={false}
              />
              <Area
                type="monotone"
                dataKey="stale"
                name="stale"
                stroke={c.statusWarn}
                strokeWidth={1}
                fill="url(#stale-fill)"
                dot={false}
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>
        <p className="text-xs text-ink-muted font-mono">
          simulated · real telemetry via marchyo-agent
        </p>
      </div>
    </div>
  );
}

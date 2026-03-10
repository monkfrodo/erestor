"use client";

import { useEffect, useState } from "react";
import { apiFetch } from "@/services/api";

interface InsightsData {
  energy: { label: string; value: number }[];
  quality: { label: string; count: number }[];
  timers: { project: string; hours: number }[];
}

function EnergyChart({ data }: { data: InsightsData["energy"] }) {
  if (!data || data.length === 0) {
    return <EmptySection label="Sem dados de energia" />;
  }

  const max = 5;
  return (
    <div className="space-y-2">
      {data.map((d, i) => {
        const pct = (d.value / max) * 100;
        const color =
          d.value >= 4
            ? "var(--ds-green)"
            : d.value === 3
              ? "var(--ds-amber)"
              : "var(--ds-red)";
        return (
          <div key={i} className="flex items-center gap-2">
            <span
              className="w-10 text-xs font-mono text-right shrink-0"
              style={{ color: "var(--ds-subtle)" }}
            >
              {d.label}
            </span>
            <div
              className="flex-1 h-5 rounded-md overflow-hidden"
              style={{ background: "var(--ds-muted)" }}
            >
              <div
                className="h-full rounded-md transition-all"
                style={{ width: `${pct}%`, background: color }}
              />
            </div>
            <span
              className="w-5 text-xs font-mono shrink-0"
              style={{ color: "var(--ds-text)" }}
            >
              {d.value}
            </span>
          </div>
        );
      })}
    </div>
  );
}

function QualityChart({ data }: { data: InsightsData["quality"] }) {
  if (!data || data.length === 0) {
    return <EmptySection label="Sem dados de qualidade" />;
  }

  const total = data.reduce((sum, d) => sum + d.count, 0);
  if (total === 0) return <EmptySection label="Sem dados de qualidade" />;

  const colorMap: Record<string, string> = {
    perdi: "var(--ds-red)",
    meh: "var(--ds-amber)",
    ok: "var(--ds-blue)",
    flow: "var(--ds-green)",
  };

  return (
    <div>
      {/* Segmented bar */}
      <div className="flex h-6 rounded-lg overflow-hidden mb-2">
        {data.map((d, i) => {
          const pct = (d.count / total) * 100;
          if (pct === 0) return null;
          return (
            <div
              key={i}
              className="transition-all"
              style={{
                width: `${pct}%`,
                background: colorMap[d.label.toLowerCase()] || "var(--ds-dim)",
              }}
            />
          );
        })}
      </div>
      {/* Legend */}
      <div className="flex flex-wrap gap-3">
        {data.map((d, i) => (
          <div key={i} className="flex items-center gap-1.5">
            <div
              className="w-2.5 h-2.5 rounded-full"
              style={{
                background: colorMap[d.label.toLowerCase()] || "var(--ds-dim)",
              }}
            />
            <span
              className="text-xs font-mono"
              style={{ color: "var(--ds-text)" }}
            >
              {d.label} ({d.count})
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

function TimerChart({ data }: { data: InsightsData["timers"] }) {
  if (!data || data.length === 0) {
    return <EmptySection label="Sem dados de timer" />;
  }

  const maxHours = Math.max(...data.map((d) => d.hours), 1);

  return (
    <div className="space-y-2">
      {data.map((d, i) => {
        const pct = (d.hours / maxHours) * 100;
        return (
          <div key={i} className="flex items-center gap-2">
            <span
              className="w-20 text-xs font-mono text-right shrink-0 truncate"
              style={{ color: "var(--ds-subtle)" }}
              title={d.project}
            >
              {d.project}
            </span>
            <div
              className="flex-1 h-5 rounded-md overflow-hidden"
              style={{ background: "var(--ds-muted)" }}
            >
              <div
                className="h-full rounded-md transition-all"
                style={{ width: `${pct}%`, background: "var(--ds-blue)" }}
              />
            </div>
            <span
              className="w-10 text-xs font-mono shrink-0"
              style={{ color: "var(--ds-text)" }}
            >
              {d.hours.toFixed(1)}h
            </span>
          </div>
        );
      })}
    </div>
  );
}

function EmptySection({ label }: { label: string }) {
  return (
    <div
      className="text-xs font-mono py-2"
      style={{ color: "var(--ds-subtle)" }}
    >
      {label}
    </div>
  );
}

function InsightCard({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div
      className="rounded-xl p-4"
      style={{ background: "var(--ds-s2)" }}
    >
      <h3
        className="text-sm font-medium mb-3"
        style={{ color: "var(--ds-bright)" }}
      >
        {title}
      </h3>
      {children}
    </div>
  );
}

export function InsightsTab() {
  const [data, setData] = useState<InsightsData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    apiFetch<InsightsData>("/v1/insights/chart-data").then((res) => {
      if (res.ok && res.data) {
        setData(res.data);
      }
      setLoading(false);
    }).catch(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div className="p-4 space-y-3">
        {[1, 2, 3].map((i) => (
          <div
            key={i}
            className="h-28 rounded-xl animate-pulse"
            style={{ background: "var(--ds-s2)" }}
          />
        ))}
      </div>
    );
  }

  return (
    <div className="p-4 overflow-y-auto h-full space-y-3">
      <InsightCard title="Energia">
        <EnergyChart data={data?.energy || []} />
      </InsightCard>

      <InsightCard title="Qualidade dos Blocos">
        <QualityChart data={data?.quality || []} />
      </InsightCard>

      <InsightCard title="Tempo por Projeto">
        <TimerChart data={data?.timers || []} />
      </InsightCard>
    </div>
  );
}

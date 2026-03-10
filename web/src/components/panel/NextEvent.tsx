"use client";

import { useContextStore } from "@/stores/contextStore";

function timeUntil(iso: string): string {
  const diffMs = new Date(iso).getTime() - Date.now();
  if (diffMs <= 0) return "agora";
  const mins = Math.floor(diffMs / 60000);
  if (mins < 60) return `${mins}min`;
  const hours = Math.floor(mins / 60);
  const remainMins = mins % 60;
  if (remainMins === 0) return `${hours}h`;
  return `${hours}h${String(remainMins).padStart(2, "0")}`;
}

export function NextEvent() {
  const nextEvent = useContextStore((s) => s.nextEvent);

  if (!nextEvent) return null;

  return (
    <div className="flex items-center gap-2 px-3.5 py-2">
      <span
        className="font-mono text-[10px] min-w-8"
        style={{ color: "var(--ds-dim)" }}
      >
        {timeUntil(nextEvent.start)}
      </span>
      <span
        className="text-[11px] truncate"
        style={{ color: "var(--ds-dim)" }}
      >
        {nextEvent.summary}
        {nextEvent.description ? ` · ${nextEvent.description}` : ""}
      </span>
    </div>
  );
}

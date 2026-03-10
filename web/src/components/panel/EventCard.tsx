"use client";

import { useContextStore, CalendarEvent } from "@/stores/contextStore";

function getProgress(event: CalendarEvent): number {
  const now = Date.now();
  const start = new Date(event.start).getTime();
  const end = new Date(event.end).getTime();
  if (now <= start) return 0;
  if (now >= end) return 100;
  return Math.round(((now - start) / (end - start)) * 100);
}

function formatTimeRange(event: CalendarEvent): string {
  const fmt = (iso: string) => {
    const d = new Date(iso);
    return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
  };
  return `${fmt(event.start)} — ${fmt(event.end)}`;
}

export function EventCard() {
  const event = useContextStore((s) => s.currentEvent);

  if (!event) {
    return (
      <div className="px-3.5 py-3">
        <p
          className="text-xs italic"
          style={{ color: "var(--ds-dim)" }}
        >
          Nenhum evento
        </p>
      </div>
    );
  }

  const progress = getProgress(event);

  return (
    <div className="px-3.5 pt-3.5 pb-3">
      <div className="flex items-start gap-2.5">
        <div
          className="w-[2.5px] rounded-sm self-stretch min-h-8 shrink-0"
          style={{ background: "var(--ds-green)" }}
        />
        <div className="flex-1 min-w-0">
          <div
            className="text-[13px] font-medium leading-tight"
            style={{ color: "var(--ds-bright)" }}
          >
            {event.summary}
          </div>
          <div
            className="text-[10.5px] mt-0.5"
            style={{ color: "var(--ds-subtle)" }}
          >
            {formatTimeRange(event)}
            {event.description ? ` · ${event.description}` : ""}
          </div>
          <div
            className="h-0.5 rounded-full mt-2"
            style={{ background: "var(--ds-border)" }}
          >
            <div
              className="h-full rounded-full transition-[width] duration-1000 linear"
              style={{
                width: `${progress}%`,
                background: "var(--ds-green)",
              }}
            />
          </div>
        </div>
      </div>
    </div>
  );
}

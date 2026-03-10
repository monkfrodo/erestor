"use client";

import { useEffect, useState } from "react";
import { apiFetch } from "@/services/api";

interface CalendarEvent {
  summary: string;
  start: string;
  end: string;
  description?: string;
}

function formatTime(isoOrTime: string): string {
  try {
    const d = new Date(isoOrTime);
    if (!isNaN(d.getTime())) {
      return d.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" });
    }
  } catch {
    // fallback
  }
  return isoOrTime.slice(0, 5);
}

function isCurrentEvent(start: string, end: string): boolean {
  const now = Date.now();
  const s = new Date(start).getTime();
  const e = new Date(end).getTime();
  return now >= s && now < e;
}

export function AgendaTab() {
  const [events, setEvents] = useState<CalendarEvent[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    apiFetch<CalendarEvent[]>("/v1/calendar/today").then((res) => {
      if (res.ok && Array.isArray(res.data)) {
        setEvents(res.data);
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
            className="h-16 rounded-xl animate-pulse"
            style={{ background: "var(--ds-s2)" }}
          />
        ))}
      </div>
    );
  }

  if (events.length === 0) {
    return (
      <div
        className="flex items-center justify-center h-full"
        style={{ color: "var(--ds-subtle)" }}
      >
        <span className="font-mono text-sm">Agenda vazia</span>
      </div>
    );
  }

  return (
    <div className="p-4 overflow-y-auto h-full">
      <h2
        className="text-sm font-medium mb-4 font-mono tracking-wide"
        style={{ color: "var(--ds-subtle)" }}
      >
        Hoje
      </h2>
      <div className="space-y-1">
        {events.map((evt, i) => {
          const current = isCurrentEvent(evt.start, evt.end);
          return (
            <div key={i} className="flex gap-3 items-start">
              {/* Time column */}
              <div
                className="w-12 shrink-0 text-right font-mono text-xs pt-3"
                style={{ color: "var(--ds-subtle)" }}
              >
                {formatTime(evt.start)}
              </div>

              {/* Event card */}
              <div
                className="flex-1 rounded-xl px-3.5 py-2.5 mb-1"
                style={{
                  background: "var(--ds-s2)",
                  borderLeft: `3px solid ${current ? "var(--ds-green)" : "var(--ds-border)"}`,
                }}
              >
                <div
                  className="text-sm font-medium"
                  style={{ color: "var(--ds-bright)" }}
                >
                  {evt.summary}
                </div>
                <div
                  className="text-xs font-mono mt-0.5"
                  style={{ color: "var(--ds-subtle)" }}
                >
                  {formatTime(evt.start)} - {formatTime(evt.end)}
                </div>
                {evt.description && (
                  <div
                    className="text-xs mt-1 line-clamp-2"
                    style={{ color: "var(--ds-text)" }}
                  >
                    {evt.description}
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

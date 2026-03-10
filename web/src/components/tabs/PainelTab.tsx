"use client";

import { EventCard } from "@/components/panel/EventCard";
import { TimerChip } from "@/components/panel/TimerChip";
import { TaskList } from "@/components/panel/TaskList";
import { NextEvent } from "@/components/panel/NextEvent";

export function PainelTab() {
  return (
    <div
      className="flex flex-col h-full overflow-y-auto"
      style={{ background: "var(--ds-bg)" }}
    >
      <EventCard />
      <TimerChip />
      <div className="h-px mx-3.5" style={{ background: "var(--ds-border)" }} />
      <NextEvent />
      <div className="h-px mx-3.5" style={{ background: "var(--ds-border)" }} />
      <TaskList />
    </div>
  );
}

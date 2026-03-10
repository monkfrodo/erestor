"use client";

import { useContextStore } from "@/stores/contextStore";
import { useEffect, useState } from "react";

function formatElapsed(startedAt: string): string {
  const elapsed = Math.floor((Date.now() - new Date(startedAt).getTime()) / 1000);
  const m = Math.floor(elapsed / 60);
  const s = elapsed % 60;
  if (m >= 60) {
    const h = Math.floor(m / 60);
    const rm = m % 60;
    return `${h}:${String(rm).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
  }
  return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
}

export function TimerChip() {
  const timer = useContextStore((s) => s.timer);
  const [display, setDisplay] = useState("");

  useEffect(() => {
    if (!timer) return;
    setDisplay(formatElapsed(timer.started_at));
    const interval = setInterval(() => {
      setDisplay(formatElapsed(timer.started_at));
    }, 1000);
    return () => clearInterval(interval);
  }, [timer]);

  if (!timer) return null;

  return (
    <div
      className="inline-flex items-baseline gap-1.5 px-2.5 py-1.5 rounded-lg mt-2.5 mx-3.5"
      style={{
        background: "var(--ds-green-dim)",
        border: "1px solid rgba(74,158,105,0.15)",
      }}
    >
      <span
        className="font-mono text-sm font-medium tracking-wide"
        style={{ color: "var(--ds-green)" }}
      >
        {display}
      </span>
      <span className="text-[10.5px]" style={{ color: "#5a7a62" }}>
        {timer.project}
        {timer.task ? ` · ${timer.task}` : ""}
      </span>
    </div>
  );
}

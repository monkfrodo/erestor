"use client";

import { DS } from "@/lib/ds";
import { usePollStore, GateAlert } from "@/stores/pollStore";

const SEVERITY_COLORS: Record<string, string> = {
  amber: DS.amber,
  red: DS.red,
  inform: DS.amber,
  urgent: DS.red,
};

export function GateModal({ gate }: { gate: GateAlert }) {
  const removeGate = usePollStore((s) => s.removeGate);

  const severityColor =
    SEVERITY_COLORS[gate.severity] || DS.amber;

  const tasks = (gate as unknown as Record<string, unknown>).tasks as
    | string[]
    | undefined;

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center"
      style={{ backgroundColor: "rgba(0,0,0,0.6)" }}
    >
      <div
        className="w-full max-w-sm mx-4 mb-4 sm:mb-0 rounded-2xl overflow-hidden animate-slide-up"
        style={{
          backgroundColor: DS.s2,
          border: `1px solid ${DS.border}`,
        }}
      >
        {/* Severity strip */}
        <div className="h-1.5" style={{ backgroundColor: severityColor }} />

        <div className="p-6">
          <h2
            className="text-lg font-semibold mb-4"
            style={{ color: DS.bright }}
          >
            {gate.message || "Bloco terminando"}
          </h2>

          {tasks && tasks.length > 0 && (
            <ul className="space-y-2 mb-6">
              {tasks.map((task, i) => (
                <li
                  key={i}
                  className="flex items-center gap-2 text-sm"
                  style={{ color: DS.text }}
                >
                  <span
                    className="w-2 h-2 rounded-full flex-shrink-0"
                    style={{ backgroundColor: DS.red }}
                  />
                  {task}
                </li>
              ))}
            </ul>
          )}

          <button
            onClick={() => removeGate(gate.id)}
            className="w-full py-3 rounded-xl font-medium text-base transition-transform active:scale-95"
            style={{
              backgroundColor: DS.muted,
              color: DS.bright,
            }}
          >
            Entendi
          </button>
        </div>
      </div>
    </div>
  );
}

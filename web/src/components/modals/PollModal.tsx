"use client";

import { useState, useCallback } from "react";
import { DS } from "@/lib/ds";
import { apiFetch } from "@/services/api";
import { usePollStore, Poll } from "@/stores/pollStore";

const ENERGY_COLORS: Record<string, string> = {
  "1": DS.red,
  "2": DS.red,
  "3": DS.amber,
  "4": DS.green,
  "5": DS.green,
};

const QUALITY_COLORS: Record<string, string> = {
  perdi: DS.red,
  meh: DS.amber,
  ok: DS.blue,
  flow: DS.green,
};

const QUALITY_LABELS: Record<string, string> = {
  perdi: "Perdi",
  meh: "Meh",
  ok: "OK",
  flow: "Flow",
};

export function PollModal({ poll }: { poll: Poll }) {
  const removePoll = usePollStore((s) => s.removePoll);
  const [submitting, setSubmitting] = useState(false);

  const isEnergy = poll.poll_type === "energy";

  const respond = useCallback(
    async (value: string) => {
      if (submitting) return;
      setSubmitting(true);
      try {
        await apiFetch(`/v1/polls/${poll.poll_id}/respond`, {
          method: "POST",
          body: JSON.stringify({ value }),
        });
      } catch {
        // Best-effort -- dismiss modal regardless
      }
      removePoll(poll.poll_id);
    },
    [poll.poll_id, removePoll, submitting]
  );

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center"
      style={{ backgroundColor: "rgba(0,0,0,0.6)" }}
    >
      <div
        className="w-full max-w-sm mx-4 mb-4 sm:mb-0 rounded-2xl p-6 animate-slide-up"
        style={{
          backgroundColor: DS.s2,
          border: `1px solid ${DS.border}`,
        }}
      >
        <h2
          className="text-center text-lg font-semibold mb-6"
          style={{ color: DS.bright }}
        >
          {isEnergy ? "Como esta sua energia?" : "Como foi o bloco?"}
        </h2>

        {isEnergy ? (
          <div className="flex justify-center gap-3">
            {["1", "2", "3", "4", "5"].map((v) => (
              <button
                key={v}
                disabled={submitting}
                onClick={() => respond(v)}
                className="w-12 h-12 rounded-xl font-bold text-lg transition-transform active:scale-95 disabled:opacity-50"
                style={{
                  backgroundColor: ENERGY_COLORS[v],
                  color: DS.bright,
                }}
              >
                {v}
              </button>
            ))}
          </div>
        ) : (
          <div className="flex flex-col gap-3">
            {["perdi", "meh", "ok", "flow"].map((v) => (
              <button
                key={v}
                disabled={submitting}
                onClick={() => respond(v)}
                className="w-full py-3 rounded-xl font-medium text-base transition-transform active:scale-95 disabled:opacity-50"
                style={{
                  backgroundColor: QUALITY_COLORS[v],
                  color: DS.bright,
                }}
              >
                {QUALITY_LABELS[v]}
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

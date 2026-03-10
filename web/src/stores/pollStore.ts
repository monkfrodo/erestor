import { create } from "zustand";

export interface Poll {
  poll_id: string;
  poll_type: "energy" | "block_quality";
  question: string;
  options: Array<{ value: string; label: string }>;
  expires_at?: string;
}

export interface GateAlert {
  id: string;
  severity: "inform" | "urgent";
  message: string;
  actions?: Array<{ label: string; action: string }>;
}

export interface PollState {
  activePolls: Poll[];
  activeGates: GateAlert[];
  addPoll: (poll: Poll) => void;
  addGate: (gate: GateAlert) => void;
  removePoll: (pollId: string) => void;
  removeGate: (gateId: string) => void;
}

export const usePollStore = create<PollState>((set) => ({
  activePolls: [],
  activeGates: [],

  addPoll: (poll) =>
    set((state) => ({
      activePolls: [
        ...state.activePolls.filter((p) => p.poll_id !== poll.poll_id),
        poll,
      ],
    })),

  addGate: (gate) =>
    set((state) => ({
      activeGates: [
        ...state.activeGates.filter((g) => g.id !== gate.id),
        gate,
      ],
    })),

  removePoll: (pollId) =>
    set((state) => ({
      activePolls: state.activePolls.filter((p) => p.poll_id !== pollId),
    })),

  removeGate: (gateId) =>
    set((state) => ({
      activeGates: state.activeGates.filter((g) => g.id !== gateId),
    })),
}));

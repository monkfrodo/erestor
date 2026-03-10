import { create } from "zustand";

export interface CalendarEvent {
  summary: string;
  start: string;
  end: string;
  description?: string;
  color?: string;
}

export interface Timer {
  project: string;
  task?: string;
  started_at: string;
  elapsed_minutes?: number;
}

export interface Task {
  name: string;
  priority?: number;
  time?: string;
  done?: boolean;
}

export interface ContextState {
  currentEvent: CalendarEvent | null;
  timer: Timer | null;
  tasks: Task[];
  nextEvent: CalendarEvent | null;
  update: (data: Partial<ContextData>) => void;
}

interface ContextData {
  current_event: CalendarEvent | null;
  active_timer: Timer | null;
  tasks: Task[];
  next_event: CalendarEvent | null;
}

export const useContextStore = create<ContextState>((set) => ({
  currentEvent: null,
  timer: null,
  tasks: [],
  nextEvent: null,
  update: (data) =>
    set({
      currentEvent: data.current_event ?? null,
      timer: data.active_timer ?? null,
      tasks: data.tasks ?? [],
      nextEvent: data.next_event ?? null,
    }),
}));

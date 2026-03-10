import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen } from "@testing-library/react";
import "@testing-library/jest-dom/vitest";

// Mock zustand stores
const mockContextState = {
  currentEvent: null as unknown,
  timer: null as unknown,
  tasks: [] as unknown[],
  nextEvent: null as unknown,
  update: vi.fn(),
};

vi.mock("@/stores/contextStore", () => ({
  useContextStore: (selector: (s: typeof mockContextState) => unknown) =>
    selector(mockContextState),
}));

describe("Panel Components", () => {
  beforeEach(() => {
    mockContextState.currentEvent = null;
    mockContextState.timer = null;
    mockContextState.tasks = [];
    mockContextState.nextEvent = null;
  });

  describe("EventCard", () => {
    it("shows empty state when no event", async () => {
      const { EventCard } = await import(
        "@/components/panel/EventCard"
      );
      render(<EventCard />);
      expect(screen.getByText("Nenhum evento")).toBeInTheDocument();
    });

    it("shows event name when currentEvent exists", async () => {
      mockContextState.currentEvent = {
        summary: "Deep Work",
        start: new Date(Date.now() - 3600000).toISOString(),
        end: new Date(Date.now() + 3600000).toISOString(),
        description: "foco Integros",
      };

      const { EventCard } = await import(
        "@/components/panel/EventCard"
      );
      render(<EventCard />);
      expect(screen.getByText("Deep Work")).toBeInTheDocument();
    });
  });

  describe("TimerChip", () => {
    it("returns null when no timer", async () => {
      const { TimerChip } = await import(
        "@/components/panel/TimerChip"
      );
      const { container } = render(<TimerChip />);
      expect(container.innerHTML).toBe("");
    });

    it("shows timer when active", async () => {
      mockContextState.timer = {
        project: "mentoria",
        started_at: new Date(Date.now() - 120000).toISOString(),
      };

      const { TimerChip } = await import(
        "@/components/panel/TimerChip"
      );
      render(<TimerChip />);
      expect(screen.getByText("mentoria")).toBeInTheDocument();
    });
  });

  describe("TaskList", () => {
    it("shows empty state when no tasks", async () => {
      const { TaskList } = await import(
        "@/components/panel/TaskList"
      );
      render(<TaskList />);
      expect(screen.getByText("Sem tarefas")).toBeInTheDocument();
    });

    it("renders correct number of tasks", async () => {
      mockContextState.tasks = [
        { name: "Gravar video", priority: 1 },
        { name: "Revisar proposta", priority: 1 },
        { name: "Responder emails", priority: 3 },
      ];

      const { TaskList } = await import(
        "@/components/panel/TaskList"
      );
      render(<TaskList />);
      expect(screen.getByText("Gravar video")).toBeInTheDocument();
      expect(screen.getByText("Revisar proposta")).toBeInTheDocument();
      expect(screen.getByText("Responder emails")).toBeInTheDocument();
    });
  });

  describe("NextEvent", () => {
    it("returns null when no next event", async () => {
      const { NextEvent } = await import(
        "@/components/panel/NextEvent"
      );
      const { container } = render(<NextEvent />);
      expect(container.innerHTML).toBe("");
    });

    it("shows next event when present", async () => {
      mockContextState.nextEvent = {
        summary: "Almoco",
        start: new Date(Date.now() + 7200000).toISOString(),
        end: new Date(Date.now() + 10800000).toISOString(),
        description: "pausa completa",
      };

      const { NextEvent } = await import(
        "@/components/panel/NextEvent"
      );
      render(<NextEvent />);
      expect(screen.getByText(/Almoco/)).toBeInTheDocument();
    });
  });

  describe("PainelTab", () => {
    it("renders all panel components", async () => {
      mockContextState.currentEvent = {
        summary: "Deep Work",
        start: new Date(Date.now() - 1800000).toISOString(),
        end: new Date(Date.now() + 5400000).toISOString(),
      };
      mockContextState.tasks = [{ name: "Task A", priority: 1 }];

      const { PainelTab } = await import(
        "@/components/tabs/PainelTab"
      );
      render(<PainelTab />);

      expect(screen.getByText("Deep Work")).toBeInTheDocument();
      expect(screen.getByText("Task A")).toBeInTheDocument();
    });
  });
});

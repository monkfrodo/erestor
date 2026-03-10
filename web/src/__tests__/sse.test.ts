import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

// Mock stores before importing SSE manager
vi.mock("@/stores/contextStore", () => ({
  useContextStore: {
    getState: vi.fn(() => ({
      update: vi.fn(),
    })),
  },
}));

vi.mock("@/stores/pollStore", () => ({
  usePollStore: {
    getState: vi.fn(() => ({
      addPoll: vi.fn(),
      addGate: vi.fn(),
    })),
  },
}));

// Mock EventSource
class MockEventSource {
  static CONNECTING = 0;
  static OPEN = 1;
  static CLOSED = 2;
  CONNECTING = 0;
  OPEN = 1;
  CLOSED = 2;

  url: string;
  readyState = 1;
  onerror: ((ev: Event) => void) | null = null;
  private listeners: Record<string, ((e: MessageEvent) => void)[]> = {};

  constructor(url: string) {
    this.url = url;
    MockEventSource.instances.push(this);
  }

  addEventListener(type: string, handler: (e: MessageEvent) => void) {
    if (!this.listeners[type]) this.listeners[type] = [];
    this.listeners[type].push(handler);
  }

  close() {
    this.readyState = 2;
  }

  // Test helper: simulate an event
  _emit(type: string, data: unknown) {
    const handlers = this.listeners[type] || [];
    const event = { data: JSON.stringify(data) } as MessageEvent;
    handlers.forEach((h) => h(event));
  }

  static instances: MockEventSource[] = [];
  static reset() {
    MockEventSource.instances = [];
  }
}

// @ts-expect-error -- mock global
globalThis.EventSource = MockEventSource;

describe("SSEManager", () => {
  beforeEach(() => {
    MockEventSource.reset();
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.resetModules();
  });

  it("connects to the correct URL with token", async () => {
    vi.stubEnv("NEXT_PUBLIC_API_URL", "http://test:8766");
    vi.stubEnv("NEXT_PUBLIC_API_TOKEN", "test-token");

    const { sseManager } = await import("@/services/sse");
    sseManager.connect();

    expect(MockEventSource.instances).toHaveLength(1);
    expect(MockEventSource.instances[0].url).toContain("/v1/events/stream");
    expect(MockEventSource.instances[0].url).toContain("token=test-token");

    sseManager.disconnect();
  });

  it("calls contextStore.update on context_update event", async () => {
    const { useContextStore } = await import("@/stores/contextStore");
    const mockUpdate = vi.fn();
    vi.mocked(useContextStore.getState).mockReturnValue({
      update: mockUpdate,
      currentEvent: null,
      timer: null,
      tasks: [],
      nextEvent: null,
    });

    const { sseManager } = await import("@/services/sse");
    sseManager.connect();

    const es = MockEventSource.instances[MockEventSource.instances.length - 1];
    es._emit("context_update", { current_event: { summary: "Test" } });

    expect(mockUpdate).toHaveBeenCalledWith({
      current_event: { summary: "Test" },
    });

    sseManager.disconnect();
  });

  it("calls pollStore.addPoll on poll_energy event", async () => {
    const { usePollStore } = await import("@/stores/pollStore");
    const mockAddPoll = vi.fn();
    vi.mocked(usePollStore.getState).mockReturnValue({
      addPoll: mockAddPoll,
      addGate: vi.fn(),
      activePolls: [],
      activeGates: [],
      removePoll: vi.fn(),
      removeGate: vi.fn(),
    });

    const { sseManager } = await import("@/services/sse");
    sseManager.connect();

    const es = MockEventSource.instances[MockEventSource.instances.length - 1];
    es._emit("poll_energy", { poll_id: "p1", poll_type: "energy" });

    expect(mockAddPoll).toHaveBeenCalledWith({
      poll_id: "p1",
      poll_type: "energy",
    });

    sseManager.disconnect();
  });

  it("reconnects with exponential backoff on error", async () => {
    const { sseManager } = await import("@/services/sse");
    sseManager.connect();

    const es = MockEventSource.instances[MockEventSource.instances.length - 1];
    const initialCount = MockEventSource.instances.length;

    // Trigger error
    es.onerror?.(new Event("error"));

    // Should not reconnect immediately
    expect(MockEventSource.instances).toHaveLength(initialCount);

    // After 3s (initial delay)
    vi.advanceTimersByTime(3000);
    expect(MockEventSource.instances.length).toBeGreaterThan(initialCount);

    sseManager.disconnect();
  });
});

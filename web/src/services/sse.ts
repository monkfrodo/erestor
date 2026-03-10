import { API_BASE, getToken } from "./api";
import { useContextStore } from "@/stores/contextStore";
import { usePollStore } from "@/stores/pollStore";

class SSEManager {
  private es: EventSource | null = null;
  private retryDelay = 3000;
  private maxDelay = 30000;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;

  connect() {
    this.disconnect();

    const token = getToken();
    const url = `${API_BASE}/v1/events/stream?token=${encodeURIComponent(token)}`;

    this.es = new EventSource(url);

    this.es.addEventListener("context_update", (e) => {
      try {
        const data = JSON.parse((e as MessageEvent).data);
        useContextStore.getState().update(data);
      } catch {
        /* ignore parse errors */
      }
    });

    this.es.addEventListener("poll_energy", (e) => {
      try {
        const data = JSON.parse((e as MessageEvent).data);
        usePollStore.getState().addPoll(data);
      } catch {
        /* ignore */
      }
    });

    this.es.addEventListener("poll_quality", (e) => {
      try {
        const data = JSON.parse((e as MessageEvent).data);
        usePollStore.getState().addPoll(data);
      } catch {
        /* ignore */
      }
    });

    this.es.addEventListener("gate_alert", (e) => {
      try {
        const data = JSON.parse((e as MessageEvent).data);
        usePollStore.getState().addGate(data);
      } catch {
        /* ignore */
      }
    });

    this.es.addEventListener("heartbeat", () => {
      this.retryDelay = 3000;
    });

    this.es.onerror = () => {
      this.es?.close();
      this.es = null;
      this.reconnectTimer = setTimeout(() => this.connect(), this.retryDelay);
      this.retryDelay = Math.min(this.retryDelay * 2, this.maxDelay);
    };
  }

  disconnect() {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    if (this.es) {
      this.es.close();
      this.es = null;
    }
    this.retryDelay = 3000;
  }

  get connected(): boolean {
    return this.es?.readyState === EventSource.OPEN;
  }
}

export const sseManager = new SSEManager();

import { create } from "zustand";

export interface ChatMessage {
  role: "user" | "assistant";
  content: string;
  timestamp: number;
}

export interface ChatState {
  messages: ChatMessage[];
  isStreaming: boolean;
  addMessage: (role: "user" | "assistant", content: string) => void;
  appendToken: (token: string) => void;
  finishStreaming: (fullResponse?: string) => void;
  clear: () => void;
}

export const useChatStore = create<ChatState>((set, get) => ({
  messages: [],
  isStreaming: false,

  addMessage: (role, content) =>
    set((state) => ({
      messages: [
        ...state.messages,
        { role, content, timestamp: Date.now() },
      ],
      isStreaming: role === "user" ? true : state.isStreaming,
    })),

  appendToken: (token) => {
    const { messages, isStreaming } = get();
    if (!isStreaming) return;

    const last = messages[messages.length - 1];
    if (last && last.role === "assistant") {
      // Mutate in place for performance (same pattern as macOS app)
      const updated = [...messages];
      updated[updated.length - 1] = {
        ...last,
        content: last.content + token,
      };
      set({ messages: updated });
    } else {
      set({
        messages: [
          ...messages,
          { role: "assistant", content: token, timestamp: Date.now() },
        ],
      });
    }
  },

  finishStreaming: (fullResponse) => {
    if (fullResponse) {
      const { messages } = get();
      const last = messages[messages.length - 1];
      if (last && last.role === "assistant") {
        const updated = [...messages];
        updated[updated.length - 1] = { ...last, content: fullResponse };
        set({ messages: updated, isStreaming: false });
        return;
      }
    }
    set({ isStreaming: false });
  },

  clear: () => set({ messages: [], isStreaming: false }),
}));

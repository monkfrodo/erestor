import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import React from "react";

// Mock react-markdown before imports
vi.mock("react-markdown", () => ({
  default: ({ children }: { children: string }) =>
    React.createElement("div", { "data-testid": "markdown" }, children),
}));
vi.mock("remark-gfm", () => ({ default: () => {} }));
vi.mock("rehype-highlight", () => ({ default: () => {} }));

import { ChatMessage } from "@/components/chat/ChatMessage";
import { ChatInput } from "@/components/chat/ChatInput";
import { useChatStore, type ChatMessage as ChatMessageType } from "@/stores/chatStore";

function makeMsg(
  role: "user" | "assistant",
  content: string
): ChatMessageType {
  return { role, content, timestamp: Date.now() };
}

describe("ChatMessage", () => {
  it("renders user message right-aligned", () => {
    const { container } = render(
      <ChatMessage message={makeMsg("user", "hello")} />
    );
    const wrapper = container.firstChild as HTMLElement;
    expect(wrapper.className).toContain("justify-end");
    expect(screen.getByText("hello")).toBeTruthy();
  });

  it("renders assistant message with markdown when not streaming", () => {
    const { container } = render(
      <ChatMessage
        message={makeMsg("assistant", "**bold text**")}
        isStreaming={false}
      />
    );
    // react-markdown renders markdown to HTML
    const wrapper = container.firstChild as HTMLElement;
    expect(wrapper.className).toContain("justify-start");
    // Check that content is rendered (not empty)
    expect(wrapper.textContent).toContain("bold");
    // Should NOT have streaming cursor
    expect(container.querySelector(".animate-pulse")).toBeNull();
  });

  it("renders streaming assistant message as plain text with cursor", () => {
    const { container } = render(
      <ChatMessage
        message={makeMsg("assistant", "loading...")}
        isStreaming={true}
      />
    );
    expect(screen.getByText("loading...")).toBeTruthy();
    // Cursor indicator (blinking span)
    const cursor = container.querySelector(".animate-pulse");
    expect(cursor).toBeTruthy();
  });
});

describe("ChatInput", () => {
  it("calls onSend on Enter key", () => {
    const onSend = vi.fn();
    render(<ChatInput onSend={onSend} />);
    const textarea = screen.getByPlaceholderText("Mensagem...");
    fireEvent.change(textarea, { target: { value: "test msg" } });
    fireEvent.keyDown(textarea, { key: "Enter", shiftKey: false });
    expect(onSend).toHaveBeenCalledWith("test msg");
  });

  it("does not send on Shift+Enter", () => {
    const onSend = vi.fn();
    render(<ChatInput onSend={onSend} />);
    const textarea = screen.getByPlaceholderText("Mensagem...");
    fireEvent.change(textarea, { target: { value: "test" } });
    fireEvent.keyDown(textarea, { key: "Enter", shiftKey: true });
    expect(onSend).not.toHaveBeenCalled();
  });

  it("is disabled when disabled prop is true", () => {
    render(<ChatInput onSend={vi.fn()} disabled={true} />);
    const textarea = screen.getByPlaceholderText("Mensagem...");
    expect(textarea).toHaveProperty("disabled", true);
  });
});

describe("streamChat SSE parsing", () => {
  beforeEach(() => {
    useChatStore.setState({ messages: [], isStreaming: true });
  });

  it("parses SSE data lines and calls appendToken", async () => {
    const chunks = [
      'data: {"text":"Hello"}\n\n',
      'data: {"text":" world"}\n\n',
      'data: {"done":true,"full_response":"Hello world"}\n\n',
    ];

    let chunkIndex = 0;
    const mockReader = {
      read: vi.fn().mockImplementation(() => {
        if (chunkIndex < chunks.length) {
          const chunk = new TextEncoder().encode(chunks[chunkIndex++]);
          return Promise.resolve({ done: false, value: chunk });
        }
        return Promise.resolve({ done: true, value: undefined });
      }),
    };

    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      body: { getReader: () => mockReader },
    });

    // Import streamChat dynamically to use mocked fetch
    const { streamChat } = await import("@/services/chat");

    // Add a user message first (so history is built)
    useChatStore.getState().addMessage("user", "test");

    await streamChat("test");

    const state = useChatStore.getState();
    expect(state.isStreaming).toBe(false);
    // Should have user msg + assistant msg
    const assistantMsgs = state.messages.filter(
      (m) => m.role === "assistant"
    );
    expect(assistantMsgs.length).toBe(1);
    expect(assistantMsgs[0].content).toBe("Hello world");
  });

  it("handles fetch error gracefully", async () => {
    global.fetch = vi.fn().mockRejectedValue(new Error("Network error"));

    const { streamChat } = await import("@/services/chat");
    useChatStore.setState({ messages: [], isStreaming: true });

    await streamChat("test");

    const state = useChatStore.getState();
    expect(state.isStreaming).toBe(false);
    const assistantMsgs = state.messages.filter(
      (m) => m.role === "assistant"
    );
    expect(assistantMsgs.length).toBe(1);
    expect(assistantMsgs[0].content).toContain("Erro");
  });
});

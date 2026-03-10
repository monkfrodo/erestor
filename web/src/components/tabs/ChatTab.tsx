"use client";

import { useRef, useEffect, useCallback } from "react";
import { useChatStore } from "@/stores/chatStore";
import { ChatMessage } from "@/components/chat/ChatMessage";
import { ChatInput } from "@/components/chat/ChatInput";
import { streamChat } from "@/services/chat";

export function ChatTab() {
  const messages = useChatStore((s) => s.messages);
  const isStreaming = useChatStore((s) => s.isStreaming);
  const addMessage = useChatStore((s) => s.addMessage);
  const bottomRef = useRef<HTMLDivElement>(null);

  // Auto-scroll on new messages and during streaming
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const handleSend = useCallback(
    (text: string) => {
      addMessage("user", text);
      streamChat(text);
    },
    [addMessage]
  );

  return (
    <div className="flex flex-col h-full">
      {/* Message list */}
      <div className="flex-1 overflow-y-auto px-3 pt-4 pb-2">
        {messages.length === 0 ? (
          <div
            className="flex items-center justify-center h-full"
            style={{ color: "var(--ds-subtle)" }}
          >
            <span className="font-mono text-sm">Converse com Erestor</span>
          </div>
        ) : (
          messages.map((msg, i) => (
            <ChatMessage
              key={`${msg.timestamp}-${i}`}
              message={msg}
              isStreaming={
                isStreaming &&
                i === messages.length - 1 &&
                msg.role === "assistant"
              }
            />
          ))
        )}
        <div ref={bottomRef} />
      </div>

      {/* Input */}
      <ChatInput onSend={handleSend} disabled={isStreaming} />
    </div>
  );
}

"use client";

import React from "react";
import type { ChatMessage as ChatMessageType } from "@/stores/chatStore";

// Lazy import markdown deps only for completed assistant messages
let ReactMarkdown: React.ComponentType<{ children: string; remarkPlugins?: unknown[]; rehypePlugins?: unknown[] }> | null = null;
let remarkGfm: unknown = null;
let rehypeHighlight: unknown = null;

function loadMarkdownDeps() {
  if (!ReactMarkdown) {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    ReactMarkdown = require("react-markdown").default;
    remarkGfm = require("remark-gfm").default;
    rehypeHighlight = require("rehype-highlight").default;
  }
}

interface ChatMessageProps {
  message: ChatMessageType;
  isStreaming?: boolean;
}

export function ChatMessage({ message, isStreaming }: ChatMessageProps) {
  const isUser = message.role === "user";

  if (isUser) {
    return (
      <div className="flex justify-end mb-3">
        <div
          className="max-w-[85%] rounded-2xl rounded-br-sm px-3.5 py-2.5 text-sm leading-relaxed"
          style={{
            background: "var(--ds-s2)",
            color: "var(--ds-bright)",
          }}
        >
          {message.content}
        </div>
      </div>
    );
  }

  // Assistant message
  if (isStreaming) {
    return (
      <div className="flex justify-start mb-3">
        <div
          className="max-w-[85%] rounded-2xl rounded-bl-sm px-3.5 py-2.5 text-sm leading-relaxed whitespace-pre-wrap"
          style={{ color: "var(--ds-text)" }}
        >
          {message.content}
          <span className="inline-block w-1.5 h-4 ml-0.5 animate-pulse" style={{ background: "var(--ds-subtle)" }} />
        </div>
      </div>
    );
  }

  // Completed assistant message -- render markdown
  loadMarkdownDeps();

  return (
    <div className="flex justify-start mb-3">
      <div
        className="max-w-[85%] rounded-2xl rounded-bl-sm px-3.5 py-2.5 text-sm leading-relaxed chat-markdown"
        style={{ color: "var(--ds-text)" }}
      >
        {ReactMarkdown && (
          <ReactMarkdown
            remarkPlugins={[remarkGfm]}
            rehypePlugins={[rehypeHighlight]}
          >
            {message.content}
          </ReactMarkdown>
        )}
      </div>
    </div>
  );
}

"use client";

import { useState, useRef, type KeyboardEvent } from "react";

interface ChatInputProps {
  onSend: (message: string) => void;
  disabled?: boolean;
}

export function ChatInput({ onSend, disabled }: ChatInputProps) {
  const [text, setText] = useState("");
  const inputRef = useRef<HTMLTextAreaElement>(null);

  function handleSend() {
    const trimmed = text.trim();
    if (!trimmed || disabled) return;
    onSend(trimmed);
    setText("");
    inputRef.current?.focus();
  }

  function handleKeyDown(e: KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  }

  return (
    <div
      className="flex items-end gap-2 p-3 shrink-0"
      style={{ borderTop: "1px solid var(--ds-border)" }}
    >
      <textarea
        ref={inputRef}
        value={text}
        onChange={(e) => setText(e.target.value)}
        onKeyDown={handleKeyDown}
        disabled={disabled}
        placeholder="Mensagem..."
        rows={1}
        className="flex-1 resize-none rounded-xl px-3.5 py-2.5 text-sm font-body outline-none"
        style={{
          background: "var(--ds-s2)",
          border: "1px solid var(--ds-border)",
          color: "var(--ds-bright)",
          maxHeight: "120px",
          opacity: disabled ? 0.5 : 1,
        }}
      />
      <button
        onClick={handleSend}
        disabled={disabled || !text.trim()}
        className="shrink-0 rounded-xl px-4 py-2.5 text-sm font-medium transition-opacity"
        style={{
          background: "var(--ds-green)",
          color: "var(--ds-bright)",
          opacity: disabled || !text.trim() ? 0.4 : 1,
        }}
      >
        Enviar
      </button>
    </div>
  );
}

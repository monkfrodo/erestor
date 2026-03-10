import { API_BASE, getToken } from "./api";
import { useChatStore } from "@/stores/chatStore";

/**
 * Stream a chat message to the backend and update chatStore with tokens.
 * Uses fetch + ReadableStream (POST not supported by EventSource API).
 */
export async function streamChat(message: string): Promise<void> {
  const store = useChatStore.getState();

  // Build history from last 20 messages
  const history = store.messages.slice(-20).map((m) => ({
    role: m.role,
    content: m.content,
  }));

  const token = getToken();

  let response: Response;
  try {
    response = await fetch(`${API_BASE}/v1/chat/stream`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify({ message, history }),
    });
  } catch (err) {
    useChatStore.getState().addMessage("assistant", "Erro de conexao com o servidor.");
    useChatStore.getState().finishStreaming();
    return;
  }

  if (!response.ok) {
    useChatStore.getState().addMessage("assistant", `Erro: HTTP ${response.status}`);
    useChatStore.getState().finishStreaming();
    return;
  }

  const reader = response.body?.getReader();
  if (!reader) {
    useChatStore.getState().addMessage("assistant", "Erro: resposta sem corpo.");
    useChatStore.getState().finishStreaming();
    return;
  }

  const decoder = new TextDecoder();
  let buffer = "";

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      // Keep last incomplete line in buffer
      buffer = lines.pop() || "";

      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed.startsWith("data:")) continue;

        const jsonStr = trimmed.slice(5).trim();
        if (!jsonStr || jsonStr === "[DONE]") continue;

        try {
          const data = JSON.parse(jsonStr);
          if (data.text) {
            useChatStore.getState().appendToken(data.text);
          }
          if (data.done) {
            useChatStore.getState().finishStreaming(data.full_response);
            return;
          }
        } catch {
          // Skip malformed JSON lines
        }
      }
    }

    // Stream ended without explicit done signal
    useChatStore.getState().finishStreaming();
  } catch (err) {
    useChatStore.getState().finishStreaming();
  }
}

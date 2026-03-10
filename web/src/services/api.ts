export const API_BASE =
  process.env.NEXT_PUBLIC_API_URL || "http://localhost:8766";

export function getToken(): string {
  return process.env.NEXT_PUBLIC_API_TOKEN || "";
}

export interface ApiResponse<T = unknown> {
  ok: boolean;
  data: T;
  error?: string;
}

export async function apiFetch<T = unknown>(
  path: string,
  options: RequestInit = {}
): Promise<ApiResponse<T>> {
  const token = getToken();
  const headers = new Headers(options.headers);
  if (token) {
    headers.set("Authorization", `Bearer ${token}`);
  }
  if (!headers.has("Content-Type") && options.body) {
    headers.set("Content-Type", "application/json");
  }

  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers,
  });

  if (!res.ok) {
    return { ok: false, data: null as T, error: `HTTP ${res.status}` };
  }

  const json = await res.json();
  return json as ApiResponse<T>;
}

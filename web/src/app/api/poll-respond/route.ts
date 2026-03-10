import { NextRequest, NextResponse } from "next/server";

const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8766";
const API_TOKEN = process.env.NEXT_PUBLIC_API_TOKEN || "";

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { poll_id, value } = body;

    if (!poll_id || !value) {
      return NextResponse.json(
        { ok: false, error: "Missing poll_id or value" },
        { status: 400 }
      );
    }

    const res = await fetch(`${API_BASE}/v1/polls/${poll_id}/respond`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(API_TOKEN ? { Authorization: `Bearer ${API_TOKEN}` } : {}),
      },
      body: JSON.stringify({ value }),
    });

    const data = await res.json();
    return NextResponse.json(data, { status: res.status });
  } catch {
    return NextResponse.json(
      { ok: false, error: "Proxy error" },
      { status: 502 }
    );
  }
}

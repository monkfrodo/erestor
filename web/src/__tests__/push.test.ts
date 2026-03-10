import { describe, it, expect, vi, beforeEach } from "vitest";

// Mock api module
vi.mock("@/services/api", () => ({
  apiFetch: vi.fn().mockResolvedValue({ ok: true, data: {} }),
}));

describe("Push Service", () => {
  beforeEach(() => {
    vi.resetModules();
    localStorage.clear();

    // Reset navigator mocks
    Object.defineProperty(window, "Notification", {
      value: { requestPermission: vi.fn() },
      writable: true,
      configurable: true,
    });
  });

  it("returns supported:false when PushManager not available", async () => {
    // Remove PushManager from window
    const origPM = (window as Record<string, unknown>).PushManager;
    delete (window as Record<string, unknown>).PushManager;

    const { requestPushPermission } = await import("@/services/push");
    const result = await requestPushPermission();

    expect(result.supported).toBe(false);

    // Restore
    (window as Record<string, unknown>).PushManager = origPM;
  });

  it("returns granted:false when permission is denied", async () => {
    // Setup PushManager
    (window as Record<string, unknown>).PushManager = {};
    Object.defineProperty(navigator, "serviceWorker", {
      value: { ready: Promise.resolve({}) },
      writable: true,
      configurable: true,
    });

    // Mock Notification.requestPermission to return denied
    (window as Record<string, unknown>).Notification = {
      requestPermission: vi.fn().mockResolvedValue("denied"),
    };

    // Set VAPID key via env
    const origEnv = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY;
    process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY = "BEl62iUYgUivxIkv69yViEuiBIa-Ib9-SkvMeAtA3LFgDzkPs-aR5K46b9f3bN-x1U78a7J8qErl7G-HN3avjUo";

    const { requestPushPermission } = await import("@/services/push");
    const result = await requestPushPermission();

    expect(result.supported).toBe(true);
    expect(result.granted).toBe(false);

    process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY = origEnv;
  });

  it("subscribePush calls pushManager.subscribe with VAPID key", async () => {
    const mockSubscription = {
      toJSON: () => ({
        endpoint: "https://fcm.googleapis.com/fcm/send/test",
        keys: { auth: "auth123", p256dh: "p256dh456" },
      }),
    };

    const mockSubscribeFn = vi.fn().mockResolvedValue(mockSubscription);

    (window as Record<string, unknown>).PushManager = {};
    Object.defineProperty(navigator, "serviceWorker", {
      value: {
        ready: Promise.resolve({
          pushManager: {
            subscribe: mockSubscribeFn,
          },
        }),
      },
      writable: true,
      configurable: true,
    });

    // Set VAPID key
    const origEnv = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY;
    process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY = "BEl62iUYgUivxIkv69yViEuiBIa-Ib9-SkvMeAtA3LFgDzkPs-aR5K46b9f3bN-x1U78a7J8qErl7G-HN3avjUo";

    const { subscribePush } = await import("@/services/push");
    const result = await subscribePush();

    expect(mockSubscribeFn).toHaveBeenCalledWith({
      userVisibleOnly: true,
      applicationServerKey: expect.any(Uint8Array),
    });
    expect(result.subscribed).toBe(true);

    process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY = origEnv;
  });

  it("subscribePush POSTs subscription to backend", async () => {
    const { apiFetch } = await import("@/services/api");

    const mockSubscription = {
      toJSON: () => ({
        endpoint: "https://push.example.com/test",
        keys: { auth: "auth_key", p256dh: "p256dh_key" },
      }),
    };

    Object.defineProperty(navigator, "serviceWorker", {
      value: {
        ready: Promise.resolve({
          pushManager: {
            subscribe: vi.fn().mockResolvedValue(mockSubscription),
          },
        }),
      },
      writable: true,
      configurable: true,
    });

    const origEnv = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY;
    process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY = "BEl62iUYgUivxIkv69yViEuiBIa-Ib9-SkvMeAtA3LFgDzkPs-aR5K46b9f3bN-x1U78a7J8qErl7G-HN3avjUo";

    const { subscribePush } = await import("@/services/push");
    await subscribePush();

    expect(apiFetch).toHaveBeenCalledWith("/v1/webpush/subscribe", {
      method: "POST",
      body: JSON.stringify({
        endpoint: "https://push.example.com/test",
        keys: { auth: "auth_key", p256dh: "p256dh_key" },
      }),
    });

    process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY = origEnv;
  });

  it("wasPushPermissionRequested returns false initially", async () => {
    const { wasPushPermissionRequested } = await import("@/services/push");
    expect(wasPushPermissionRequested()).toBe(false);
  });
});

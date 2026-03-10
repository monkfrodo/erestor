/**
 * Web Push notification subscription management.
 *
 * Handles permission requests, VAPID-based push subscriptions,
 * and backend registration/deregistration.
 */

import { apiFetch } from "./api";

const VAPID_PUBLIC_KEY = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY || "";

const PUSH_PERMISSION_KEY = "erestor_push_asked";

/**
 * Convert a URL-safe base64 VAPID key to a Uint8Array
 * required by PushManager.subscribe().
 */
function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding)
    .replace(/-/g, "+")
    .replace(/_/g, "/");

  const rawData = atob(base64);
  const outputArray = new Uint8Array(rawData.length);
  for (let i = 0; i < rawData.length; i++) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}

export interface PushResult {
  supported: boolean;
  granted?: boolean;
  subscribed?: boolean;
  error?: string;
}

/**
 * Request push notification permission and subscribe if granted.
 * Does NOT request on page load -- should be called after first user interaction.
 * Stores state in localStorage to avoid re-prompting.
 */
export async function requestPushPermission(): Promise<PushResult> {
  if (!("serviceWorker" in navigator) || !("PushManager" in window)) {
    return { supported: false };
  }

  if (!VAPID_PUBLIC_KEY) {
    return { supported: true, error: "VAPID key not configured" };
  }

  const permission = await Notification.requestPermission();
  if (permission !== "granted") {
    localStorage.setItem(PUSH_PERMISSION_KEY, "denied");
    return { supported: true, granted: false };
  }

  localStorage.setItem(PUSH_PERMISSION_KEY, "granted");

  const result = await subscribePush();
  return { supported: true, granted: true, ...result };
}

/**
 * Subscribe to web push via the service worker and register with backend.
 */
export async function subscribePush(): Promise<{
  subscribed: boolean;
  error?: string;
}> {
  try {
    const registration = await navigator.serviceWorker.ready;

    const subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY) as BufferSource,
    });

    const subJson = subscription.toJSON();

    const res = await apiFetch("/v1/webpush/subscribe", {
      method: "POST",
      body: JSON.stringify({
        endpoint: subJson.endpoint,
        keys: {
          auth: subJson.keys?.auth || "",
          p256dh: subJson.keys?.p256dh || "",
        },
      }),
    });

    if (!res.ok) {
      return { subscribed: false, error: res.error || "Backend registration failed" };
    }

    return { subscribed: true };
  } catch (err) {
    return {
      subscribed: false,
      error: err instanceof Error ? err.message : "Subscription failed",
    };
  }
}

/**
 * Unsubscribe from web push and deregister from backend.
 */
export async function unsubscribePush(): Promise<void> {
  try {
    const registration = await navigator.serviceWorker.ready;
    const subscription = await registration.pushManager.getSubscription();

    if (subscription) {
      const endpoint = subscription.endpoint;
      await subscription.unsubscribe();

      await apiFetch("/v1/webpush/subscribe", {
        method: "DELETE",
        body: JSON.stringify({ endpoint }),
      });
    }

    localStorage.removeItem(PUSH_PERMISSION_KEY);
  } catch {
    // Best-effort cleanup
  }
}

/**
 * Check if push permission was already requested (avoids re-prompting).
 */
export function wasPushPermissionRequested(): boolean {
  if (typeof window === "undefined") return false;
  return localStorage.getItem(PUSH_PERMISSION_KEY) !== null;
}

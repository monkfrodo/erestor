// Service worker -- push notifications only (no offline caching)

self.addEventListener("push", function (event) {
  if (!event.data) return;

  const data = event.data.json();
  const options = {
    body: data.body,
    icon: "/icon-192x192.png",
    badge: "/icon-192x192.png",
    tag: data.tag || "erestor",
    data: data.payload || {},
    vibrate: [100, 50, 100],
  };

  // Action buttons (progressive enhancement -- works on Chrome, ignored on Safari)
  if (data.actions) {
    options.actions = data.actions;
  }

  event.waitUntil(
    self.registration.showNotification(data.title || "Erestor", options)
  );
});

self.addEventListener("notificationclick", function (event) {
  event.notification.close();

  const action = event.action;
  const payload = event.notification.data;

  if (action && payload.poll_id) {
    // Action button clicked -- respond to poll via API proxy
    event.waitUntil(
      fetch(`${self.location.origin}/api/poll-respond`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          poll_id: payload.poll_id,
          value: action,
        }),
      }).then(() => {
        return clients.openWindow("/");
      })
    );
  } else {
    // Notification body clicked -- open/focus the PWA
    event.waitUntil(
      clients.matchAll({ type: "window" }).then((windowClients) => {
        for (const client of windowClients) {
          if (client.url.includes(self.location.origin) && "focus" in client) {
            return client.focus();
          }
        }
        return clients.openWindow("/");
      })
    );
  }
});

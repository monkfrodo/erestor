import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Erestor",
    short_name: "Erestor",
    description: "Personal intelligence assistant",
    start_url: "/",
    display: "standalone",
    background_color: "#1a1816",
    theme_color: "#1e1c1a",
    icons: [
      { src: "/icon-192x192.png", sizes: "192x192", type: "image/png" },
      { src: "/icon-512x512.png", sizes: "512x512", type: "image/png" },
    ],
  };
}

import { describe, it, expect } from "vitest";
import manifest from "@/app/manifest";

describe("PWA Manifest", () => {
  const m = manifest();

  it("has correct app name", () => {
    expect(m.name).toBe("Erestor");
    expect(m.short_name).toBe("Erestor");
  });

  it("uses standalone display mode", () => {
    expect(m.display).toBe("standalone");
  });

  it("uses DS.bg as background color", () => {
    expect(m.background_color).toBe("#1a1816");
  });

  it("uses DS.surface as theme color", () => {
    expect(m.theme_color).toBe("#1e1c1a");
  });

  it("has PWA icons in correct sizes", () => {
    expect(m.icons).toHaveLength(2);
    expect(m.icons).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ sizes: "192x192", type: "image/png" }),
        expect.objectContaining({ sizes: "512x512", type: "image/png" }),
      ])
    );
  });

  it("has start_url set to /", () => {
    expect(m.start_url).toBe("/");
  });
});

"use client";

import { ReactNode } from "react";
import { PainelTab } from "@/components/tabs/PainelTab";

export type DesktopTabId = "chat" | "agenda" | "insights";

interface DesktopTab {
  id: DesktopTabId;
  label: string;
}

const TABS: DesktopTab[] = [
  { id: "chat", label: "Chat" },
  { id: "agenda", label: "Agenda" },
  { id: "insights", label: "Insights" },
];

interface DesktopLayoutProps {
  activeTab: DesktopTabId;
  onTabChange: (tab: DesktopTabId) => void;
  children: ReactNode;
}

export function DesktopLayout({
  activeTab,
  onTabChange,
  children,
}: DesktopLayoutProps) {
  return (
    <div className="hidden md:flex h-screen">
      <aside
        className="w-[360px] shrink-0 overflow-auto"
        style={{ borderRight: "1px solid var(--ds-border)" }}
      >
        <PainelTab />
      </aside>
      <div className="flex-1 flex flex-col min-w-0">
        <nav
          className="flex gap-1 px-3 py-2 shrink-0"
          style={{ borderBottom: "1px solid var(--ds-border)" }}
        >
          {TABS.map((tab) => {
            const active = tab.id === activeTab;
            return (
              <button
                key={tab.id}
                onClick={() => onTabChange(tab.id)}
                className="px-3 py-1 rounded text-xs font-mono transition-colors"
                style={{
                  color: active ? "var(--ds-bright)" : "var(--ds-subtle)",
                  background: active ? "var(--ds-s2)" : "transparent",
                }}
              >
                {tab.label}
              </button>
            );
          })}
        </nav>
        <main className="flex-1 overflow-auto">{children}</main>
      </div>
    </div>
  );
}

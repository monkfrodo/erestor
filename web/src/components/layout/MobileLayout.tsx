"use client";

import { ReactNode } from "react";

export type TabId = "painel" | "chat" | "agenda" | "insights";

interface Tab {
  id: TabId;
  label: string;
  icon: string;
}

const TABS: Tab[] = [
  { id: "painel", label: "Painel", icon: "◉" },
  { id: "chat", label: "Chat", icon: "◇" },
  { id: "agenda", label: "Agenda", icon: "▦" },
  { id: "insights", label: "Insights", icon: "△" },
];

interface MobileLayoutProps {
  activeTab: TabId;
  onTabChange: (tab: TabId) => void;
  children: ReactNode;
}

export function MobileLayout({
  activeTab,
  onTabChange,
  children,
}: MobileLayoutProps) {
  return (
    <div className="h-screen flex flex-col md:hidden">
      <main className="flex-1 overflow-auto">{children}</main>
      <nav
        className="flex shrink-0"
        style={{ borderTop: "1px solid var(--ds-border)" }}
      >
        {TABS.map((tab) => {
          const active = tab.id === activeTab;
          return (
            <button
              key={tab.id}
              onClick={() => onTabChange(tab.id)}
              className="flex-1 flex flex-col items-center gap-0.5 py-2 transition-colors"
              style={{
                background: "var(--ds-surface)",
                color: active ? "var(--ds-bright)" : "var(--ds-subtle)",
              }}
            >
              <span className="text-base">{tab.icon}</span>
              <span className="text-[9px] font-mono tracking-wide">
                {tab.label}
              </span>
            </button>
          );
        })}
      </nav>
    </div>
  );
}

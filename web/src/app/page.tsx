"use client";

import { useEffect, useState } from "react";
import { sseManager } from "@/services/sse";
import { MobileLayout, TabId } from "@/components/layout/MobileLayout";
import {
  DesktopLayout,
  DesktopTabId,
} from "@/components/layout/DesktopLayout";
import { PainelTab } from "@/components/tabs/PainelTab";

function PlaceholderTab({ name }: { name: string }) {
  return (
    <div
      className="flex items-center justify-center h-full"
      style={{ color: "var(--ds-subtle)" }}
    >
      <span className="font-mono text-sm">{name}</span>
    </div>
  );
}

function getTabContent(tab: TabId | DesktopTabId) {
  switch (tab) {
    case "painel":
      return <PainelTab />;
    case "chat":
      return <PlaceholderTab name="Chat" />;
    case "agenda":
      return <PlaceholderTab name="Agenda" />;
    case "insights":
      return <PlaceholderTab name="Insights" />;
  }
}

export default function Home() {
  const [mobileTab, setMobileTab] = useState<TabId>("painel");
  const [desktopTab, setDesktopTab] = useState<DesktopTabId>("chat");

  useEffect(() => {
    sseManager.connect();
    return () => sseManager.disconnect();
  }, []);

  return (
    <>
      <MobileLayout activeTab={mobileTab} onTabChange={setMobileTab}>
        {getTabContent(mobileTab)}
      </MobileLayout>
      <DesktopLayout activeTab={desktopTab} onTabChange={setDesktopTab}>
        {getTabContent(desktopTab)}
      </DesktopLayout>
    </>
  );
}

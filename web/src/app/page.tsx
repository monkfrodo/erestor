"use client";

import { useEffect, useRef, useState } from "react";
import { sseManager } from "@/services/sse";
import { requestPushPermission, wasPushPermissionRequested } from "@/services/push";
import { MobileLayout, TabId } from "@/components/layout/MobileLayout";
import {
  DesktopLayout,
  DesktopTabId,
} from "@/components/layout/DesktopLayout";
import { PainelTab } from "@/components/tabs/PainelTab";
import { ChatTab } from "@/components/tabs/ChatTab";
import { AgendaTab } from "@/components/tabs/AgendaTab";
import { InsightsTab } from "@/components/tabs/InsightsTab";
import { PollModal } from "@/components/modals/PollModal";
import { GateModal } from "@/components/modals/GateModal";
import { usePollStore } from "@/stores/pollStore";

function getTabContent(tab: TabId | DesktopTabId) {
  switch (tab) {
    case "painel":
      return <PainelTab />;
    case "chat":
      return <ChatTab />;
    case "agenda":
      return <AgendaTab />;
    case "insights":
      return <InsightsTab />;
  }
}

export default function Home() {
  const [mobileTab, setMobileTab] = useState<TabId>("painel");
  const [desktopTab, setDesktopTab] = useState<DesktopTabId>("chat");

  const activePolls = usePollStore((s) => s.activePolls);
  const activeGates = usePollStore((s) => s.activeGates);

  const pushRequested = useRef(false);

  useEffect(() => {
    sseManager.connect();
    return () => sseManager.disconnect();
  }, []);

  // Request push permission after first user interaction (not on load)
  useEffect(() => {
    if (pushRequested.current) return;
    if (wasPushPermissionRequested()) {
      pushRequested.current = true;
      return;
    }

    const handler = () => {
      if (pushRequested.current) return;
      pushRequested.current = true;
      requestPushPermission().catch(() => {});
      document.removeEventListener("click", handler);
    };

    document.addEventListener("click", handler, { once: true });
    return () => document.removeEventListener("click", handler);
  }, []);

  const currentPoll = activePolls.length > 0 ? activePolls[0] : null;
  const currentGate = activeGates.length > 0 ? activeGates[0] : null;

  return (
    <>
      <MobileLayout activeTab={mobileTab} onTabChange={setMobileTab}>
        {getTabContent(mobileTab)}
      </MobileLayout>
      <DesktopLayout activeTab={desktopTab} onTabChange={setDesktopTab}>
        {getTabContent(desktopTab)}
      </DesktopLayout>

      {/* Modal layer -- renders on top of everything */}
      {currentPoll && <PollModal poll={currentPoll} />}
      {!currentPoll && currentGate && <GateModal gate={currentGate} />}
    </>
  );
}

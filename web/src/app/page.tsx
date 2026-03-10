"use client";

import { useEffect, useState } from "react";
import { sseManager } from "@/services/sse";
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

  useEffect(() => {
    sseManager.connect();
    return () => sseManager.disconnect();
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

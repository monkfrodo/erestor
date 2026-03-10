"use client";

import { useContextStore, Task } from "@/stores/contextStore";

function priorityColor(p?: number): string {
  switch (p) {
    case 1:
      return "var(--ds-red)";
    case 2:
      return "var(--ds-amber)";
    default:
      return "var(--ds-dim)";
  }
}

function TaskRow({ task }: { task: Task }) {
  return (
    <div className="flex items-start gap-2 py-0.5">
      <div
        className="w-1 h-1 rounded-full mt-[5px] shrink-0"
        style={{ background: priorityColor(task.priority) }}
      />
      <span className="text-[11.5px] leading-relaxed" style={{ color: "#8a7d73" }}>
        {task.name}
        {task.time ? (
          <span className="ml-1.5 font-mono text-[10px]" style={{ color: "var(--ds-dim)" }}>
            {task.time}
          </span>
        ) : null}
      </span>
    </div>
  );
}

export function TaskList() {
  const tasks = useContextStore((s) => s.tasks);

  if (!tasks.length) {
    return (
      <div className="px-3.5 py-2">
        <p className="text-[11px] italic" style={{ color: "var(--ds-dim)" }}>
          Sem tarefas
        </p>
      </div>
    );
  }

  return (
    <div className="px-3.5 py-2">
      {tasks.map((task, i) => (
        <TaskRow key={`${task.name}-${i}`} task={task} />
      ))}
    </div>
  );
}

import { useState } from "react";
import { brewCommands } from "../links.ts";
import type { Workload } from "../simulation.ts";
import { CopyCommand } from "./CopyCommand.tsx";
import { Panel } from "./panel/Panel.tsx";

export function Hero() {
  return (
    <section id="top" className="mx-auto max-w-5xl px-6 pt-16 sm:pt-24">
      <div className="mx-auto flex max-w-2xl flex-col items-center text-center">
        <img src="/icon.png" alt="" width={112} height={112} className="size-24 sm:size-28" />
        <h1 className="mt-8 text-4xl font-semibold tracking-[-0.03em] text-balance text-white sm:text-6xl">
          Fan control for your Mac.
        </h1>
        <p className="mt-5 max-w-xl text-lg leading-relaxed text-pretty text-neutral-400">
          A small menu bar app that shows your Mac's temperatures and puts you in charge of its fans.
        </p>
        <CopyCommand commands={brewCommands} className="mt-10 w-full max-w-xl text-left" />
        <p className="mt-4 text-sm text-neutral-500">
          or{" "}
          <a href="#download" className="text-neutral-300 underline decoration-neutral-600 underline-offset-4 transition-colors hover:text-white">
            download the app
          </a>{" "}
          · Apple silicon, macOS 26 or later
        </p>
      </div>
      <Desktop />
    </section>
  );
}

/** The app's panel, live, over a wallpaper. */
function Desktop() {
  const [workload, setWorkload] = useState<Workload>("normal");
  return (
    <div className="relative mt-16 overflow-hidden rounded-2xl border border-white/10 sm:mt-20 sm:rounded-3xl">
      <div
        aria-hidden="true"
        className="absolute inset-0"
        style={{
          background:
            "radial-gradient(120% 90% at 15% 0%, #4c5fd7 0%, transparent 55%), radial-gradient(90% 80% at 100% 100%, #b04aa8 0%, transparent 60%), linear-gradient(160deg, #1d2257 0%, #2a1c4a 55%, #120f24 100%)",
        }}
      />
      <div className="relative flex flex-col items-center gap-8 px-4 py-10 sm:flex-row sm:justify-between sm:px-16 sm:py-14">
        <div className="flex max-w-xs flex-col items-center text-center sm:items-start sm:text-left">
          <p className="text-lg font-medium text-white">Try it.</p>
          <p className="mt-2 leading-relaxed text-white/70">
            This is the real panel, running on a simulated Mac. Switch modes, drag the slider or the curve, then press
            Apply and watch the fans respond.
          </p>
          <WorkloadPicker workload={workload} onChange={setWorkload} />
        </div>
        <Panel workload={workload} />
      </div>
    </div>
  );
}

const workloads: { id: Workload; title: string }[] = [
  { id: "light", title: "Light" },
  { id: "normal", title: "Normal" },
  { id: "stress", title: "Stress test" },
];

/** Sets what the simulated Mac is doing; styled as part of the page, not the app. */
function WorkloadPicker({ workload, onChange }: { workload: Workload; onChange: (workload: Workload) => void }) {
  return (
    <div className="mt-8">
      <p className="text-xs font-medium tracking-wide text-white/50 uppercase">Simulated workload</p>
      <div role="radiogroup" aria-label="Simulated workload" className="mt-3 flex flex-wrap gap-2">
        {workloads.map(({ id, title }) => (
          <button
            key={id}
            role="radio"
            aria-checked={id === workload}
            onClick={() => onChange(id)}
            className={`rounded-full px-3.5 py-1.5 text-sm font-medium transition-colors ${
              id === workload ? "bg-white text-neutral-900" : "border border-white/20 text-white/80 hover:bg-white/10"
            }`}
          >
            {title}
          </button>
        ))}
      </div>
    </div>
  );
}

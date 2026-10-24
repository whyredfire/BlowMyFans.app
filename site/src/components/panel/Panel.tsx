import { useEffect, useRef, useState, type ReactNode } from "react";
import { defaultPoints } from "../../curve.ts";
import { initialMachine, isUnderThermalPressure, step, type Configuration, type Workload } from "../../simulation.ts";
import { CurveEditor, ModePicker, SpeedSlider } from "./Controls.tsx";
import { FanRow, TemperatureRow, ThermalPressureRow } from "./Rows.tsx";
import { Symbol } from "./Symbol.tsx";

const initialConfiguration: Configuration = { mode: "curve", manualRPM: 3900, curve: defaultPoints };
/** Matches the app's default update interval. */
const tick = 2000;

/** The draft's mode with only that mode's settings, as the app applies it. */
function pending(applied: Configuration, draft: Configuration): Configuration {
  return {
    mode: draft.mode,
    manualRPM: draft.mode === "manual" ? draft.manualRPM : applied.manualRPM,
    curve: draft.mode === "curve" ? draft.curve : applied.curve,
  };
}

const isSame = (a: Configuration, b: Configuration) =>
  a.mode === b.mode && a.manualRPM === b.manualRPM && JSON.stringify(a.curve) === JSON.stringify(b.curve);

/** The menu bar panel, running against a simulated Mac. */
export function Panel({ workload }: { workload: Workload }) {
  const [applied, setApplied] = useState(initialConfiguration);
  const [draft, setDraft] = useState(initialConfiguration);
  const [machine, setMachine] = useState(initialMachine);
  // The timer reads these through refs so it never restarts.
  const appliedRef = useRef(applied);
  appliedRef.current = applied;
  const workloadRef = useRef(workload);
  workloadRef.current = workload;

  useEffect(() => {
    let last = performance.now();
    const timer = setInterval(() => {
      const now = performance.now();
      const dt = Math.min((now - last) / 1000, 2);
      last = now;
      // Nothing to show while the tab is hidden.
      if (!document.hidden) setMachine((machine) => step(machine, appliedRef.current, workloadRef.current, dt));
    }, tick);
    return () => clearInterval(timer);
  }, []);

  const next = pending(applied, draft);
  const hasChanges = !isSame(next, applied);

  return (
    // A faint Liquid Glass finish: slightly translucent over the wallpaper, with a soft rim and top sheen.
    <div className="w-[340px] space-y-3.5 rounded-[22px] border border-white/12 bg-[#2a2a2a]/85 bg-linear-to-b from-white/[0.05] via-transparent to-transparent p-4 text-[13px] leading-[17px] text-white/90 shadow-[0_24px_60px_rgb(0_0_0/0.45),inset_0_1px_0_rgb(255_255_255/0.14),inset_0_0_0_1px_rgb(255_255_255/0.03)] backdrop-blur-2xl backdrop-saturate-150">
      <ModePicker mode={draft.mode} onChange={(mode) => setDraft({ ...draft, mode })} />

      {draft.mode === "manual" && <SpeedSlider rpm={draft.manualRPM} onChange={(manualRPM) => setDraft({ ...draft, manualRPM })} />}
      {draft.mode === "curve" && (
        <CurveEditor points={draft.curve} temperature={machine.smoothedTemperature} onChange={(curve) => setDraft({ ...draft, curve })} />
      )}

      <hr className="border-white/10" />
      <div className="space-y-3">
        <FanRow name="Left side" rpm={machine.fans[0]} />
        <FanRow name="Right side" rpm={machine.fans[1]} />
      </div>

      <hr className="border-white/10" />
      <div className="space-y-2.5">
        <ThermalPressureRow isFair={isUnderThermalPressure(machine)} />
        <TemperatureRow icon="cpu" name="CPU Core" celsius={machine.cpu} />
        <TemperatureRow icon="cube" name="GPU Cluster" celsius={machine.gpu} />
        <TemperatureRow icon="internaldrive" name="SSD" celsius={machine.ssd} />
        <TemperatureRow icon="battery.75percent" name="Battery" celsius={machine.battery} />
        <TemperatureRow icon="powerplug" name="Power Supply" celsius={machine.powerSupply} />
      </div>

      <hr className="border-white/10" />
      <div className="flex items-center gap-2">
        <FooterButton label="Settings (in the app)">
          <Symbol name="gearshape" />
        </FooterButton>
        {hasChanges && (
          <div className="mx-auto flex gap-2">
            <button
              onClick={() => setDraft(applied)}
              className="h-8 rounded-full border border-white/10 bg-white/[0.08] px-4 shadow-[inset_0_1px_0_rgb(255_255_255/0.1)] transition-colors hover:bg-white/15"
            >
              Cancel
            </button>
            <button
              onClick={() => {
                setApplied(next);
                setDraft(next);
              }}
              className="h-8 rounded-full bg-[#a35fae] px-4 font-medium text-white shadow-[inset_0_1px_0_rgb(255_255_255/0.25)] transition-colors hover:bg-[#b06cb8]"
            >
              Apply
            </button>
          </div>
        )}
        <FooterButton label="Quit (in the app)" className="ml-auto">
          <Symbol name="power" />
        </FooterButton>
      </div>
    </div>
  );
}

/** Settings and Quit only do something in the real app. */
function FooterButton({ label, className = "", children }: { label: string; className?: string; children: ReactNode }) {
  return (
    <span
      title={label}
      className={`flex h-8 w-11 items-center justify-center rounded-full border border-white/10 bg-white/[0.08] shadow-[inset_0_1px_0_rgb(255_255_255/0.1)] ${className}`}
    >
      {children}
    </span>
  );
}

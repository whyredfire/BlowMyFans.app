import { fanRange } from "../../simulation.ts";
import { Symbol, type SymbolName } from "./Symbol.tsx";

/** The leading icon column every row shares. */
function Icon({ name }: { name: SymbolName }) {
  return (
    <span className="flex w-[18px] shrink-0 justify-center">
      <Symbol name={name} className="opacity-55" />
    </span>
  );
}

export function FanRow({ name, rpm }: { name: string; rpm: number }) {
  return (
    <div className="space-y-1.5">
      <div className="flex items-center gap-2">
        <Icon name="fan" />
        <span>{name}</span>
        <span className="ml-auto text-white/50 tabular-nums">
          {rpm > 0 ? `${Math.round(rpm).toLocaleString("en-US")} RPM` : "Off"}
        </span>
      </div>
      <div className="ml-[26px] h-1 rounded-full bg-white/12">
        <div
          className="h-full rounded-full bg-linear-to-b from-[#c88fcf] to-[#a865b1] transition-[width] duration-700 ease-out"
          style={{ width: `${Math.min(rpm / fanRange.max, 1) * 100}%` }}
        />
      </div>
    </div>
  );
}

type PowerNode = { symbol: SymbolName; title: string; watts: number };

/** Where the power comes from, the adapter or the battery, and where it goes, as the app shows it. */
export function PowerFlowRow({ watts, chargingWatts, isPluggedIn }: { watts: number; chargingWatts: number; isPluggedIn: boolean }) {
  const sources: PowerNode[] = isPluggedIn
    ? [{ symbol: "bolt.fill", title: "Power adapter", watts: watts + chargingWatts }]
    : [{ symbol: "battery.75percent", title: "Battery", watts }];
  const destinations: PowerNode[] = [
    { symbol: "laptopcomputer", title: "This Mac", watts },
    ...(chargingWatts > 0 ? [{ symbol: "battery.100percent.bolt" as const, title: "Charging", watts: chargingWatts }] : []),
  ];
  return (
    <div className="flex items-center gap-2.5" aria-label={[...sources, ...destinations].map((node) => `${node.title} ${wattsText(node.watts)}`).join(", ")}>
      <PowerColumn nodes={sources} />
      <Symbol name="arrow.right" className="opacity-35" />
      <PowerColumn nodes={destinations} />
    </div>
  );
}

function PowerColumn({ nodes }: { nodes: PowerNode[] }) {
  return (
    <div className="flex flex-1 flex-col gap-1.5">
      {nodes.map((node) => (
        <PowerBox key={node.symbol} {...node} />
      ))}
    </div>
  );
}

function PowerBox({ symbol, title, watts }: PowerNode) {
  return (
    <div title={title} className="flex items-center justify-center gap-2 rounded-[10px] bg-white/[0.06] py-[9px] text-white/55">
      <Symbol name={symbol} className="opacity-90" />
      <span className="tabular-nums">{wattsText(watts)}</span>
    </div>
  );
}

/** One decimal below 10 W, as the app shows it. */
const wattsText = (watts: number) => `${watts < 10 ? watts.toFixed(1) : Math.round(watts)} W`;

export function ThermalPressureRow({ isFair }: { isFair: boolean }) {
  return (
    <div className="flex items-center gap-2">
      <Icon name="gauge.with.dots.needle.50percent" />
      <span>Thermal pressure</span>
      <span className={`ml-auto size-[7px] rounded-full ${isFair ? "bg-yellow-400" : "bg-[#32d74b]"}`} />
      <span className="text-white/50">{isFair ? "Fair" : "Nominal"}</span>
    </div>
  );
}

export function TemperatureRow({ icon, name, celsius }: { icon: SymbolName; name: string; celsius: number }) {
  const tint = celsius >= 95 ? "text-[#ff453a]" : celsius >= 80 ? "text-[#ff9f0a]" : "text-white/90";
  return (
    <div className="flex items-center gap-2">
      <Icon name={icon} />
      <span>{name}</span>
      <span className={`ml-auto tabular-nums ${tint}`}>{Math.round(celsius)}°</span>
    </div>
  );
}

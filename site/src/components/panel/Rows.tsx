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

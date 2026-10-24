// A small stand-in for a Mac, so the demo panel has temperatures and fans that behave like real ones.
//
// Temperature follows a heat balance: the workload puts heat in, and heat leaves in proportion to how
// far the chip is above room temperature, a little through the chassis alone and much more with the
// fans spinning. With the fans off it climbs quickly; once they run it settles where heat in matches
// heat out. Past 100 °C the chip throttles, as Apple silicon does, and reports thermal pressure.
//
// Fan speed comes from the mode: Auto follows a curve shaped like macOS's own, which keeps the fans off
// into the 60s and lets the chip run hot before they get loud.
import { speedAt, type CurvePoint } from "./curve.ts";

export type Mode = "automatic" | "manual" | "curve" | "fullBlast";
export type Configuration = { mode: Mode; manualRPM: number; curve: CurvePoint[] };
/** What the simulated Mac is busy with: light stays cool, normal has bursts of load, stress never lets up. */
export type Workload = "light" | "normal" | "stress";

/** The speed range a 14-inch MacBook Pro with an M4 Pro reports for its fans. */
export const fanRange = { min: 2317, max: 7826 } as const;

/** macOS's curve: off until the mid-60s, a gentle rise through the 80s, steep past 90 °C. */
const autoCurve: CurvePoint[] = [
  { id: 0, temperature: 45, speed: 0 },
  { id: 1, temperature: 64, speed: 0 },
  { id: 2, temperature: 90, speed: 0.22 },
  { id: 3, temperature: 110, speed: 0.85 },
];

/** Running fans stop only once the chip is back below this. */
const autoStopTemperature = 60;
/** Seconds macOS lags behind the chip: fans always ramp up a little after it heats, and wind down slower still. */
const autoLag = { rising: 8, falling: 20 };

const ambient = 25;
/** Joules per °C: how quickly the chip and heatsink warm for a given excess of heat. */
const heatCapacity = 10;
/** Watts per °C above ambient that the chassis sheds on its own, and that the fans add at full speed. */
const conductance = { passive: 0.23, fans: 0.66 };
/** Watts each workload draws; normal alternates between idle and bursts. */
const power = { light: 4, idle: 5, burst: 28, stress: 45 };

export type Machine = {
  /** Hottest CPU core. */
  cpu: number;
  gpu: number;
  ssd: number;
  battery: number;
  powerSupply: number;
  /** The CPU temperature Curve mode follows, smoothed as in the app. */
  smoothedTemperature: number;
  /** The slower-moving CPU temperature macOS's Auto curve follows. */
  autoTemperature: number;
  fans: [number, number];
  isUnderLoad: boolean;
  /** Seconds until the normal workload switches between idle and a burst. */
  phaseLeft: number;
};

export const initialMachine: Machine = {
  cpu: 47,
  gpu: 46,
  ssd: 35,
  battery: 32,
  powerSupply: 42,
  smoothedTemperature: 47,
  autoTemperature: 47,
  fans: [0, 0],
  isUnderLoad: false,
  phaseLeft: 8,
};

const clamp = (value: number, min: number, max: number) => Math.min(Math.max(value, min), max);
const random = (min: number, max: number) => min + Math.random() * (max - min);
/** Moves `value` towards `target` as a first-order lag with time constant `tau`. */
const approach = (value: number, target: number, tau: number, dt: number) => value + (target - value) * (1 - Math.exp(-dt / tau));
const rpmFor = (fraction: number) => fanRange.min + fraction * (fanRange.max - fanRange.min);

/** Curve mode's speed for a temperature, as the app computes it: 0% stops the fans. */
export function curveRPM(curve: CurvePoint[], celsius: number) {
  const fraction = speedAt(curve, celsius);
  return fraction === 0 ? 0 : clamp(Math.round(rpmFor(fraction) / 50) * 50, fanRange.min, fanRange.max);
}

function targetRPM(machine: Machine, configuration: Configuration) {
  switch (configuration.mode) {
    case "automatic": {
      // At 0% macOS stops the fans, but once they run they stay at minimum until the chip has cooled
      // a few degrees below where they started, rather than flicking on and off.
      const fraction = speedAt(autoCurve, machine.autoTemperature);
      if (fraction > 0) return rpmFor(fraction);
      return machine.fans[0] > 0 && machine.autoTemperature > autoStopTemperature ? fanRange.min : 0;
    }
    case "manual":
      return configuration.manualRPM < fanRange.min ? 0 : clamp(configuration.manualRPM, fanRange.min, fanRange.max);
    case "curve":
      return curveRPM(configuration.curve, machine.smoothedTemperature);
    case "fullBlast":
      return fanRange.max;
  }
}

/** Advances the machine by `dt` seconds with `configuration` applied while running `workload`. */
export function step(machine: Machine, configuration: Configuration, workload: Workload, dt: number): Machine {
  let { isUnderLoad, phaseLeft } = machine;
  phaseLeft -= dt;
  if (phaseLeft <= 0) {
    isUnderLoad = !isUnderLoad;
    phaseLeft = isUnderLoad ? random(9, 15) : random(15, 25);
  }
  const watts = { light: power.light, normal: isUnderLoad ? power.burst : power.idle, stress: power.stress }[workload];

  // Heat balance: settles at ambient + power / conductance, at a pace set by the heat capacity.
  const airflow = (machine.fans[0] + machine.fans[1]) / 2 / fanRange.max;
  const shedding = conductance.passive + conductance.fans * airflow;
  // Past 100 °C the chip cuts its own power to keep from running away.
  const throttle = clamp(1 - (machine.cpu - 100) / 10, 0.4, 1);
  const balance = ambient + (watts * throttle) / shedding;
  const cpu = approach(machine.cpu, balance, heatCapacity / shedding, dt) + random(-0.5, 0.5);

  const weightPerTwoSeconds = cpu > machine.smoothedTemperature ? 0.5 : 0.15;
  const smoothedTemperature =
    machine.smoothedTemperature + (cpu - machine.smoothedTemperature) * (1 - Math.pow(1 - weightPerTwoSeconds, dt / 2));

  const autoLagSeconds = cpu > machine.autoTemperature ? autoLag.rising : autoLag.falling;
  const autoTemperature = approach(machine.autoTemperature, cpu, autoLagSeconds, dt);

  const target = targetRPM({ ...machine, smoothedTemperature, autoTemperature }, configuration);
  const fans = machine.fans.map((rpm) => {
    if (target === 0) {
      const slowed = approach(rpm, 0, 1.5, dt);
      return slowed < 900 ? 0 : slowed;
    }
    // Real fans never read exactly the same, so each wobbles a little around its target.
    return approach(rpm === 0 ? 600 : rpm, target, 1.2, dt) + random(-12, 12);
  }) as [number, number];

  return {
    cpu,
    gpu: approach(machine.gpu, cpu - 1.5 + random(-1, 1), 5, dt),
    ssd: approach(machine.ssd, 34 + (cpu - 45) * 0.15, 20, dt),
    battery: approach(machine.battery, 32 + (cpu - 45) * 0.05, 40, dt),
    powerSupply: approach(machine.powerSupply, 41 + (cpu - 45) * 0.1, 15, dt),
    smoothedTemperature,
    autoTemperature,
    fans,
    isUnderLoad,
    phaseLeft,
  };
}

/** macOS reports thermal pressure once the chip stays past about 100 °C, not for a passing spike. */
export const isUnderThermalPressure = (machine: Machine) => machine.cpu > 102;

import { Fragment, useRef, useState, type MouseEvent, type PointerEvent } from "react";
import { addPoint, movePoint, removePoint, speedAt, temperatureRange, type CurvePoint } from "../../curve.ts";
import { curveRPM, fanRange, type Mode } from "../../simulation.ts";

const accent = "#b06cb8";
const modes: { id: Mode; title: string }[] = [
  { id: "automatic", title: "Auto" },
  { id: "manual", title: "Manual" },
  { id: "curve", title: "Curve" },
  { id: "fullBlast", title: "Full Blast" },
];

export function ModePicker({ mode, onChange }: { mode: Mode; onChange: (mode: Mode) => void }) {
  const selected = modes.findIndex((item) => item.id === mode);
  return (
    <div role="radiogroup" aria-label="Mode" className="flex h-[30px] items-center rounded-full border border-white/10 bg-white/[0.04] p-[3px] shadow-[inset_0_1px_0_rgb(255_255_255/0.08)]">
      {modes.map((item, index) => (
        <Fragment key={item.id}>
          {/* macOS draws a separator only between two unselected segments */}
          {index > 0 && (
            <span
              className={`h-3.5 w-px shrink-0 ${index === selected || index - 1 === selected ? "bg-transparent" : "bg-white/20"}`}
            />
          )}
          <button
            role="radio"
            aria-checked={item.id === mode}
            onClick={() => onChange(item.id)}
            className={`h-full flex-1 rounded-full text-[13px] font-medium whitespace-nowrap text-white/90 transition-colors ${
              item.id === mode ? "bg-white/15 shadow-[inset_0_1px_0_rgb(255_255_255/0.12)]" : "hover:bg-white/[0.06]"
            }`}
          >
            {item.title}
          </button>
        </Fragment>
      ))}
    </div>
  );
}

/** "Off" is one notch below the minimum, as in the app's slider. */
const sliderStart = fanRange.min - (fanRange.max - fanRange.min) * 0.05;

/** One speed for every fan, snapped to 50 RPM like the app's slider. */
export function SpeedSlider({ rpm, onChange }: { rpm: number; onChange: (rpm: number) => void }) {
  const track = useRef<HTMLDivElement>(null);
  const fraction = (Math.max(rpm, sliderStart) - sliderStart) / (fanRange.max - sliderStart);
  const set = (value: number) =>
    onChange(value < (sliderStart + fanRange.min) / 2 ? 0 : Math.min(Math.max(Math.round(value / 50) * 50, fanRange.min), fanRange.max));

  function drag(event: PointerEvent<HTMLDivElement>) {
    const bounds = track.current!.getBoundingClientRect();
    set(sliderStart + ((event.clientX - bounds.left) / bounds.width) * (fanRange.max - sliderStart));
  }

  /** Arrow keys step through the speeds, with Off just below the minimum. */
  function nudge(delta: number) {
    if (rpm < fanRange.min) return set(delta > 0 ? fanRange.min : 0);
    if (rpm === fanRange.min && delta < 0) return set(0);
    set(Math.max(rpm + delta, fanRange.min));
  }

  return (
    <div className="space-y-1">
      <div className="flex items-baseline">
        <span className="text-white/50">All fans</span>
        <span className="ml-auto font-medium tabular-nums">{rpm < fanRange.min ? "Off" : `${rpm.toLocaleString("en-US")} RPM`}</span>
      </div>
      <div
        ref={track}
        role="slider"
        tabIndex={0}
        aria-label="Speed for all fans"
        aria-valuemin={0}
        aria-valuemax={fanRange.max}
        aria-valuenow={rpm}
        aria-valuetext={rpm < fanRange.min ? "Off" : `${rpm} RPM`}
        className="relative flex h-5 cursor-pointer touch-none items-center outline-none"
        onPointerDown={(event) => {
          event.currentTarget.setPointerCapture(event.pointerId);
          drag(event);
        }}
        onPointerMove={(event) => event.buttons === 1 && drag(event)}
        onKeyDown={(event) => {
          const delta = { ArrowRight: 100, ArrowUp: 100, ArrowLeft: -100, ArrowDown: -100 }[event.key];
          if (delta) {
            event.preventDefault();
            nudge(delta);
          }
        }}
      >
        <div className="h-[5px] w-full rounded-full bg-white/12">
          <div className="h-full rounded-full" style={{ width: `${fraction * 100}%`, background: accent }} />
        </div>
        <div
          className="absolute h-[17px] w-[25px] -translate-x-1/2 rounded-full bg-[#e4e4e4] shadow-[0_1px_3px_rgb(0_0_0/0.4)]"
          style={{ left: `calc(12.5px + ${fraction} * (100% - 25px))` }}
        />
      </div>
    </div>
  );
}

const width = 308;
const height = 150;
const plot = { left: 34, right: 2, top: 6, bottom: 20 };
const plotWidth = width - plot.left - plot.right;
const plotHeight = height - plot.top - plot.bottom;
const span = temperatureRange.max - temperatureRange.min;
const x = (celsius: number) => plot.left + ((celsius - temperatureRange.min) / span) * plotWidth;
const y = (speed: number) => plot.top + (1 - speed) * plotHeight;

/** The app's curve editor: drag points, double-click to add or remove one. */
export function CurveEditor({
  points,
  temperature,
  onChange,
}: {
  points: CurvePoint[];
  temperature: number;
  onChange: (points: CurvePoint[]) => void;
}) {
  const [dragging, setDragging] = useState<number | null>(null);
  const svg = useRef<SVGSVGElement>(null);
  const celsius = Math.min(Math.max(temperature, temperatureRange.min), temperatureRange.max);
  const speed = speedAt(points, celsius);

  const samples: string[] = [];
  for (let t = temperatureRange.min; t <= temperatureRange.max; t += 0.5) {
    samples.push(`${x(t).toFixed(1)},${y(speedAt(points, t)).toFixed(1)}`);
  }
  const line = `M${samples.join("L")}`;
  const area = `${line}L${x(temperatureRange.max)},${y(0)}L${x(temperatureRange.min)},${y(0)}Z`;

  function valueAt(event: PointerEvent | MouseEvent) {
    const bounds = svg.current!.getBoundingClientRect();
    const px = ((event.clientX - bounds.left) / bounds.width) * width;
    const py = ((event.clientY - bounds.top) / bounds.height) * height;
    return { celsius: temperatureRange.min + ((px - plot.left) / plotWidth) * span, speed: 1 - (py - plot.top) / plotHeight };
  }

  /** The point under the pointer, within a comfortable hit radius. */
  function pointAt(event: MouseEvent) {
    const bounds = svg.current!.getBoundingClientRect();
    const px = ((event.clientX - bounds.left) / bounds.width) * width;
    const py = ((event.clientY - bounds.top) / bounds.height) * height;
    return points.find((point) => Math.hypot(x(point.temperature) - px, y(point.speed) - py) <= 10);
  }

  return (
    <div className="space-y-1.5">
      <svg
        ref={svg}
        viewBox={`0 0 ${width} ${height}`}
        className="w-full touch-none select-none"
        aria-label="Fan curve: drag points to adjust, double-click to add or remove a point"
        onPointerMove={(event) => {
          if (dragging === null) return;
          const value = valueAt(event);
          onChange(movePoint(points, dragging, value.celsius, value.speed));
        }}
        onPointerUp={() => setDragging(null)}
        onPointerCancel={() => setDragging(null)}
        // Decided here rather than on each point: pressing a point captures the pointer for dragging, so
        // the double-click arrives at the chart either way.
        onDoubleClick={(event) => {
          const hit = pointAt(event);
          if (hit) return onChange(removePoint(points, hit.id));
          const value = valueAt(event);
          onChange(addPoint(points, value.celsius, value.speed));
        }}
      >
        <defs>
          <linearGradient id="panel-curve-fill" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0" stopColor={accent} stopOpacity="0.28" />
            <stop offset="1" stopColor={accent} stopOpacity="0.02" />
          </linearGradient>
        </defs>
        {[40, 60, 80, 100].map((t) => (
          <g key={t}>
            <line x1={x(t)} x2={x(t)} y1={plot.top} y2={y(0)} stroke="white" strokeOpacity={0.08} strokeWidth={0.5} />
            <text x={x(t)} y={height - 4} textAnchor="middle" fontSize={10} fill="white" fillOpacity={0.5}>
              {t}°
            </text>
          </g>
        ))}
        {[0, 0.5, 1].map((value) => (
          <g key={value}>
            <line x1={plot.left} x2={width - plot.right} y1={y(value)} y2={y(value)} stroke="white" strokeOpacity={0.08} strokeWidth={0.5} />
            <text x={plot.left - 6} y={y(value) + 3.5} textAnchor="end" fontSize={10} fill="white" fillOpacity={0.5}>
              {value * 100}%
            </text>
          </g>
        ))}
        <path d={area} fill="url(#panel-curve-fill)" />
        <path d={line} fill="none" stroke={accent} strokeWidth={2.5} strokeLinecap="round" strokeLinejoin="round" />
        <line x1={x(celsius)} x2={x(celsius)} y1={plot.top} y2={y(0)} stroke="white" strokeOpacity={0.3} strokeDasharray="2 3" />
        {points.map((point) => (
          <circle
            key={point.id}
            cx={x(point.temperature)}
            cy={y(point.speed)}
            r={dragging === point.id ? 8 : 5.5}
            fill="white"
            stroke={accent}
            strokeWidth={2.5}
            className="cursor-grab drop-shadow-[0_1px_1.5px_rgb(0_0_0/0.35)] transition-[r] active:cursor-grabbing"
            onPointerDown={(event) => {
              event.currentTarget.ownerSVGElement?.setPointerCapture(event.pointerId);
              setDragging(point.id);
            }}
          />
        ))}
        <circle cx={x(celsius)} cy={y(speed)} r={4.5} fill="#ff9f0a" className="drop-shadow-[0_0_4px_rgb(255_159_10/0.7)]" />
      </svg>
      <p className="text-[11px] text-white/50 tabular-nums">
        CPU {Math.round(temperature)}° → {speed === 0 ? "Off" : `${Math.round(speed * 100)}% (${curveRPM(points, temperature).toLocaleString("en-US")} RPM)`}
      </p>
    </div>
  );
}

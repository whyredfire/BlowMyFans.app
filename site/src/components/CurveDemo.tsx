import { useRef, useState, type MouseEvent, type PointerEvent } from "react";
import { addPoint, defaultPoints, movePoint, removePoint, speedAt, temperatureRange, type CurvePoint } from "../curve.ts";

const width = 640;
const height = 300;
const plot = { left: 60, right: 16, top: 16, bottom: 36 };
const plotWidth = width - plot.left - plot.right;
const plotHeight = height - plot.top - plot.bottom;
const span = temperatureRange.max - temperatureRange.min;
/** Stands in for the live CPU temperature the app marks on its curve. */
const exampleTemperature = 66;

const x = (celsius: number) => plot.left + ((celsius - temperatureRange.min) / span) * plotWidth;
const y = (speed: number) => plot.top + (1 - speed) * plotHeight;

export function CurveDemo() {
  const [points, setPoints] = useState<CurvePoint[]>(defaultPoints);
  const [dragging, setDragging] = useState<number | null>(null);
  const svg = useRef<SVGSVGElement>(null);

  const samples: string[] = [];
  for (let celsius = temperatureRange.min; celsius <= temperatureRange.max; celsius += 0.5) {
    samples.push(`${x(celsius).toFixed(1)},${y(speedAt(points, celsius)).toFixed(1)}`);
  }
  const line = `M${samples.join("L")}`;
  const area = `${line}L${x(temperatureRange.max)},${y(0)}L${x(temperatureRange.min)},${y(0)}Z`;
  const speed = speedAt(points, exampleTemperature);

  /** The curve value under the pointer, as temperature and speed. */
  function valueAt(event: PointerEvent | MouseEvent) {
    const bounds = svg.current!.getBoundingClientRect();
    const px = ((event.clientX - bounds.left) / bounds.width) * width;
    const py = ((event.clientY - bounds.top) / bounds.height) * height;
    return {
      celsius: temperatureRange.min + ((px - plot.left) / plotWidth) * span,
      speed: 1 - (py - plot.top) / plotHeight,
    };
  }

  return (
    <section id="curve" className="mx-auto max-w-5xl scroll-mt-8 px-6 pt-32">
      <div className="grid gap-12 lg:grid-cols-[1fr_1.4fr] lg:items-center">
        <div>
          <h2 className="text-3xl font-semibold tracking-[-0.02em] text-balance text-white sm:text-4xl">
            Draw the curve. Walter follows it.
          </h2>
          <p className="mt-5 leading-relaxed text-pretty text-neutral-400">
            The curve stays smooth and never dips as things heat up. It follows a smoothed CPU temperature, so a short
            spike doesn't send the fans surging.
          </p>
          <p className="mt-4 text-sm leading-relaxed text-neutral-500">
            Try it as you would in the app: drag a point, or double-click to add or remove one. The orange dot marks
            the CPU temperature; 0% is the fans' minimum speed and 100% their maximum.
          </p>
        </div>

        <figure className="rounded-2xl border border-white/10 bg-neutral-900/60 p-4 sm:p-6">
          <svg
            ref={svg}
            viewBox={`0 0 ${width} ${height}`}
            className="w-full touch-none select-none"
            role="img"
            aria-label={`Fan curve: at ${exampleTemperature}° the fans run at ${Math.round(speed * 100)}%`}
            onPointerMove={(event) => {
              if (dragging === null) return;
              const value = valueAt(event);
              setPoints((points) => movePoint(points, dragging, value.celsius, value.speed));
            }}
            onPointerUp={() => setDragging(null)}
            onPointerCancel={() => setDragging(null)}
            onDoubleClick={(event) => {
              const value = valueAt(event);
              setPoints((points) => addPoint(points, value.celsius, value.speed));
            }}
          >
            <defs>
              <linearGradient id="curve-fill" x1="0" x2="0" y1="0" y2="1">
                <stop offset="0" stopColor="var(--color-accent)" stopOpacity="0.28" />
                <stop offset="1" stopColor="var(--color-accent)" stopOpacity="0" />
              </linearGradient>
            </defs>
            {[0, 0.5, 1].map((value) => (
              <g key={value}>
                <line x1={plot.left} x2={width - plot.right} y1={y(value)} y2={y(value)} className="stroke-white/8" />
                <text x={plot.left - 12} y={y(value) + 5} textAnchor="end" className="fill-neutral-500 text-[15px]">
                  {value * 100}%
                </text>
              </g>
            ))}
            {[40, 60, 80, 100].map((celsius) => (
              <text key={celsius} x={x(celsius)} y={height - 8} textAnchor="middle" className="fill-neutral-500 text-[15px]">
                {celsius}°
              </text>
            ))}
            <path d={area} fill="url(#curve-fill)" />
            <path d={line} fill="none" stroke="var(--color-accent)" strokeWidth={2.5} strokeLinecap="round" strokeLinejoin="round" />
            <line
              x1={x(exampleTemperature)}
              x2={x(exampleTemperature)}
              y1={plot.top}
              y2={y(0)}
              strokeDasharray="2 4"
              className="stroke-white/30"
            />
            <circle cx={x(exampleTemperature)} cy={y(speed)} r={6} className="fill-orange-400" />
            {points.map((point) => (
              <circle
                key={point.id}
                cx={x(point.temperature)}
                cy={y(point.speed)}
                r={dragging === point.id ? 9 : 7}
                strokeWidth={2.5}
                className="cursor-grab fill-white stroke-(--color-accent) transition-[r] active:cursor-grabbing"
                onPointerDown={(event) => {
                  event.currentTarget.ownerSVGElement?.setPointerCapture(event.pointerId);
                  setDragging(point.id);
                }}
                onDoubleClick={(event) => {
                  event.stopPropagation();
                  setPoints((points) => removePoint(points, point.id));
                }}
              />
            ))}
          </svg>
          <figcaption className="mt-3 text-sm text-neutral-500 tabular-nums">
            CPU {exampleTemperature}° → {Math.round(speed * 100)}%
          </figcaption>
        </figure>
      </div>
    </section>
  );
}

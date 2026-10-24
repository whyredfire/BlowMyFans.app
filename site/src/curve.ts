// Port of the app's FanCurve: a smooth curve through points sorted by temperature that never goes
// down as temperature rises.

export type CurvePoint = { id: number; temperature: number; speed: number };

export const temperatureRange = { min: 30, max: 110 } as const;
/** Keeps neighbouring points apart so the curve stays a function of temperature. */
const spacing = 2;

export const defaultPoints: CurvePoint[] = [
  { id: 0, temperature: 45, speed: 0 },
  { id: 1, temperature: 60, speed: 0.25 },
  { id: 2, temperature: 75, speed: 0.6 },
  { id: 3, temperature: 90, speed: 1 },
];

const clamp = (value: number, min: number, max: number) => Math.min(Math.max(value, min), max);

/** Steffen's monotone slope at a point; zero at the ends so the curve meets its flat extensions smoothly. */
function slope(points: CurvePoint[], index: number) {
  const previous = points[index - 1];
  const point = points[index];
  const next = points[index + 1];
  if (!previous || !point || !next) return 0;
  const h0 = point.temperature - previous.temperature;
  const h1 = next.temperature - point.temperature;
  const s0 = (point.speed - previous.speed) / h0;
  const s1 = (next.speed - point.speed) / h1;
  if (s0 <= 0 || s1 <= 0) return 0;
  const parabolic = (s0 * h1 + s1 * h0) / (h0 + h1);
  return 2 * Math.min(s0, s1, 0.5 * parabolic);
}

/** Cubic Hermite interpolation that passes through every point without overshooting. */
export function speedAt(points: CurvePoint[], celsius: number) {
  const first = points[0];
  const last = points[points.length - 1];
  if (!first || !last) return 1;
  if (celsius <= first.temperature) return first.speed;
  if (celsius >= last.temperature) return last.speed;
  const index = points.findLastIndex((point) => point.temperature <= celsius);
  const a = points[index]!;
  const b = points[index + 1]!;
  const width = b.temperature - a.temperature;
  const t = (celsius - a.temperature) / width;
  const t2 = t * t;
  const t3 = t2 * t;
  const value =
    (2 * t3 - 3 * t2 + 1) * a.speed +
    (t3 - 2 * t2 + t) * width * slope(points, index) +
    (-2 * t3 + 3 * t2) * b.speed +
    (t3 - t2) * width * slope(points, index + 1);
  return clamp(value, 0, 1);
}

/**
 * Moves a point between its neighbours' temperatures. Raising it lifts later points to at least
 * its speed; lowering it brings earlier points down to at most its speed.
 */
export function movePoint(points: CurvePoint[], id: number, temperature: number, speed: number) {
  const index = points.findIndex((point) => point.id === id);
  if (index < 0) return points;
  const lower = index > 0 ? points[index - 1]!.temperature + spacing : temperatureRange.min;
  const upper = index < points.length - 1 ? points[index + 1]!.temperature - spacing : temperatureRange.max;
  const newSpeed = clamp(speed, 0, 1);
  return points.map((point, i) => {
    if (i === index) return { ...point, temperature: Math.round(clamp(temperature, lower, upper)), speed: newSpeed };
    if (i > index) return { ...point, speed: Math.max(point.speed, newSpeed) };
    return { ...point, speed: Math.min(point.speed, newSpeed) };
  });
}

/** Adds a point unless it's too close to another, keeping speeds between its neighbours'. */
export function addPoint(points: CurvePoint[], temperature: number, speed: number) {
  const celsius = Math.round(temperature);
  if (celsius < temperatureRange.min || celsius > temperatureRange.max) return points;
  if (points.some((point) => Math.abs(point.temperature - celsius) < spacing)) return points;
  const index = points.findIndex((point) => point.temperature > celsius);
  const at = index < 0 ? points.length : index;
  const floor = points[at - 1]?.speed ?? 0;
  const ceiling = points[at]?.speed ?? 1;
  const id = Math.max(...points.map((point) => point.id)) + 1;
  return points.toSpliced(at, 0, { id, temperature: celsius, speed: clamp(speed, floor, ceiling) });
}

/** Removes a point, keeping at least two. */
export function removePoint(points: CurvePoint[], id: number) {
  return points.length > 2 ? points.filter((point) => point.id !== id) : points;
}

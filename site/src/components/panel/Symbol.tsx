/** SF Symbols rendered from macOS at the panel's 13 pt size, in points. */
const sizes = {
  fan: [17, 16],
  "fan.fill": [17, 16],
  cpu: [16, 15],
  cube: [16, 17],
  internaldrive: [18, 13],
  "battery.75percent": [22, 11],
  powerplug: [19, 12],
  "gauge.with.dots.needle.50percent": [15, 15],
  gearshape: [16, 16],
  power: [15, 16],
  "bolt.fill": [13, 17],
  laptopcomputer: [22, 13],
  "battery.100percent.bolt": [22, 14],
  "arrow.right": [16, 12],
} as const;

export type SymbolName = keyof typeof sizes;

export function Symbol({ name, className = "" }: { name: SymbolName; className?: string }) {
  const [width, height] = sizes[name];
  return <img src={`/symbols/${name}.png`} alt="" width={width} height={height} className={className} />;
}

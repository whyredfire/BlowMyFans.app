import { ChartSpline, Feather, Gauge, ShieldCheck, SlidersHorizontal, Thermometer } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { Glass } from "./Glass.tsx";

const features: { icon: LucideIcon; title: string; text: string }[] = [
  {
    icon: SlidersHorizontal,
    title: "Four modes",
    text: "Auto, Manual, Curve and Full Blast, right in the menu bar. Browse freely; nothing changes until you press Apply.",
  },
  {
    icon: ChartSpline,
    title: "Your own fan curve",
    text: "Drag points to shape how the fans answer CPU temperature. Short spikes are smoothed out, so the fans don't surge and fall.",
  },
  {
    icon: Thermometer,
    title: "Every temperature",
    text: "CPU, GPU, SSD, battery and more, with readable names for your Mac's model. Keep the hottest CPU in the menu bar.",
  },
  {
    icon: Gauge,
    title: "Thermal pressure",
    text: "See when macOS starts holding your Mac back to keep it cool, with a coloured dot on the menu bar icon.",
  },
  {
    icon: ShieldCheck,
    title: "Safe by design",
    text: "Fans go back to macOS whenever Walter quits, crashes or your Mac sleeps. If macOS isn't ready to take them, they run at full speed until it is.",
  },
  {
    icon: Feather,
    title: "Featherweight",
    text: "Native Swift that reads only what's on screen. Well under 1% CPU in the background, and its helper sleeps when it has nothing to do.",
  },
];

export function Features() {
  return (
    <section id="features" className="mx-auto max-w-6xl scroll-mt-20 px-6 py-24">
      <SectionHeading eyebrow="Features" title="Everything you need, nothing you don't." />
      <div className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {features.map(({ icon: Icon, title, text }) => (
          <Glass key={title} className="p-6">
            <span className="flex size-10 items-center justify-center rounded-xl bg-accent/15 text-accent-soft">
              <Icon className="size-5" />
            </span>
            <h3 className="mt-5 font-semibold text-white">{title}</h3>
            <p className="mt-2 text-sm leading-relaxed text-white/55">{text}</p>
          </Glass>
        ))}
      </div>
    </section>
  );
}

export function SectionHeading({ eyebrow, title, text }: { eyebrow: string; title: string; text?: string }) {
  return (
    <div className="max-w-2xl">
      <p className="text-sm font-medium text-accent-soft">{eyebrow}</p>
      <h2 className="mt-2 text-3xl font-semibold tracking-tight text-balance text-white sm:text-4xl">{title}</h2>
      {text && <p className="mt-4 leading-relaxed text-pretty text-white/55">{text}</p>}
    </div>
  );
}

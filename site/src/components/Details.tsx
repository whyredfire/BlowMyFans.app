import type { ReactNode } from "react";
import { translateURL } from "../links.ts";

const details: { title: string; text: ReactNode }[] = [
  { title: "Every sensor", text: "CPU, GPU, SSD, battery and more, named for your Mac's model. Keep any of them in the menu bar, in °C or °F." },
  { title: "Where the power goes", text: "See whether your Mac runs on the adapter or the battery, what it draws, and how fast it charges." },
  { title: "Your panel", text: "Hide the sections you don't need and pick which temperatures it lists." },
  { title: "Plugged in or on battery", text: "Give each its own mode, like Curve at your desk and Auto on the go. It switches as you plug in or unplug." },
  { title: "Thermal pressure", text: "A coloured dot on the icon when macOS starts slowing your Mac down to cool it." },
  { title: "Hands back cleanly", text: "Fans return to macOS when the app quits, crashes, hangs or your Mac sleeps. If macOS isn't ready, or your Mac gets too hot, they run at full speed." },
  { title: "Barely there", text: "It reads only what's on screen: well under 1% CPU, and its helper sleeps when there's nothing to do." },
  { title: "Keeps itself current", text: "Signed updates install in the background, without stealing focus." },
  {
    title: "Speaks your language",
    text: (
      <>
        Follows your Mac's language, in Chinese, Dutch, French, German, Italian, Japanese, Polish, Portuguese, Russian
        and Spanish.{" "}
        <a href={translateURL} className="text-neutral-200 underline decoration-neutral-600 underline-offset-4 transition-colors hover:text-white">
          Help translate
        </a>
      </>
    ),
  },
];

/** Screenshots of each Settings tab, at their size in points. */
const settingsTabs = [
  { name: "general", title: "General settings", height: 636 },
  { name: "panel", title: "Choosing what the panel shows", height: 546 },
  { name: "advanced", title: "The helper and updates", height: 477 },
];

export function Details() {
  return (
    <section className="mx-auto max-w-5xl px-6 pt-32">
      <h2 className="text-3xl font-semibold tracking-[-0.02em] text-white sm:text-4xl">The details.</h2>
      <div className="mt-12 grid gap-12 lg:grid-cols-[1fr_400px] lg:items-start">
        <dl className="grid gap-x-12 sm:grid-cols-2 lg:grid-cols-1">
          {details.map(({ title, text }) => (
            <div key={title} className="border-t border-white/10 py-6">
              <dt className="font-medium text-white">{title}</dt>
              <dd className="mt-2 leading-relaxed text-neutral-400">{text}</dd>
            </div>
          ))}
        </dl>
        <div className="mx-auto grid max-w-[400px] items-start sm:max-w-none sm:grid-cols-3 lg:grid-cols-1">
          {settingsTabs.map(({ name, title, height }) => (
            <img key={name} src={`/screenshots/settings-${name}.webp`} alt={title} width={572} height={height} loading="lazy" className="w-full" />
          ))}
        </div>
      </div>
    </section>
  );
}

import { useState } from "react";

const modes = [
  { id: "auto", title: "Auto", text: "macOS runs the fans as it always does. Walter just shows you what's going on.", screenshot: "panel-auto.png" },
  { id: "manual", title: "Manual", text: "One slider for every fan. Allow it in Settings and the lowest notch stops them while your Mac is idle.", screenshot: "panel-manual.png" },
  { id: "curve", title: "Curve", text: "The fans follow a curve you draw against CPU temperature.", screenshot: "panel-curve.png" },
  { id: "fullBlast", title: "Full Blast", text: "Every fan at maximum, for when you want it cool right now.", screenshot: "panel-fullblast.png" },
] as const;

export function Modes() {
  const [selected, setSelected] = useState<(typeof modes)[number]["id"]>("manual");

  return (
    <section id="modes" className="mx-auto max-w-5xl scroll-mt-8 px-6 pt-32">
      <h2 className="text-3xl font-semibold tracking-[-0.02em] text-white sm:text-4xl">Four modes, one click away.</h2>
      <p className="mt-5 max-w-xl leading-relaxed text-pretty text-neutral-400">
        Everything sits in one panel under the menu bar icon. Look around freely: nothing changes until you press
        Apply. The first time you apply a mode other than Auto, Walter asks for your password to install the small
        helper that sets fan speeds.
      </p>
      <div className="mt-12 grid gap-10 md:grid-cols-[1fr_auto] md:items-start">
        <ul className="divide-y divide-white/10 border-y border-white/10">
          {modes.map(({ id, title, text }) => (
            <li key={id}>
              <button
                onClick={() => setSelected(id)}
                aria-pressed={id === selected}
                className="group flex w-full gap-6 py-5 text-left"
              >
                <span
                  className={`w-24 shrink-0 font-medium transition-colors ${
                    id === selected ? "text-white" : "text-neutral-500 group-hover:text-neutral-300"
                  }`}
                >
                  {title}
                </span>
                <span className={`transition-colors ${id === selected ? "text-neutral-300" : "text-neutral-500"}`}>{text}</span>
              </button>
            </li>
          ))}
        </ul>
        {/* Sized for the tallest screenshot, so switching modes doesn't move the page */}
        <div className="relative mx-auto aspect-[680/1140] w-[260px] sm:w-[280px]">
          {modes.map(({ id, title, screenshot }) => (
            <img
              key={id}
              src={`/screenshots/${screenshot}`}
              alt={`Walter's panel in ${title} mode`}
              className={`absolute inset-x-0 top-0 w-full rounded-[22px] drop-shadow-2xl transition-opacity duration-300 ${
                id === selected ? "opacity-100" : "pointer-events-none opacity-0"
              }`}
            />
          ))}
        </div>
      </div>
    </section>
  );
}

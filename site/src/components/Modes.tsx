import { useState } from "react";
import { SectionHeading } from "./Features.tsx";
import { Glass } from "./Glass.tsx";

const modes = [
  {
    id: "auto",
    title: "Auto",
    text: "macOS runs the fans exactly as it normally would. Walter just keeps an eye on things.",
    screenshot: "panel-auto.png",
  },
  {
    id: "manual",
    title: "Manual",
    text: "One slider sets every fan. If you allow it in Settings, the leftmost notch turns them off while your Mac is idle.",
    screenshot: "panel-manual.png",
  },
  {
    id: "curve",
    title: "Curve",
    text: "Fans follow a smooth curve you draw against CPU temperature. Double-click to add or remove points.",
    screenshot: "panel-curve.png",
  },
  {
    id: "fullblast",
    title: "Full Blast",
    text: "Every fan at maximum, for when you want your Mac as cool as it can be right now.",
    screenshot: "panel-fullblast.png",
  },
] as const;

export function Modes() {
  const [selected, setSelected] = useState<(typeof modes)[number]["id"]>("curve");
  const mode = modes.find((mode) => mode.id === selected) ?? modes[0];

  return (
    <section id="modes" className="mx-auto max-w-6xl scroll-mt-20 px-6 py-24">
      <div className="grid items-center gap-14 lg:grid-cols-2">
        <div>
          <SectionHeading
            eyebrow="Modes"
            title="Pick how your fans behave."
            text="Everything lives in one panel under the menu bar icon, next to live fan speeds and temperatures."
          />
          <div role="tablist" aria-label="Fan modes" className="mt-10 inline-flex rounded-full border border-white/10 bg-white/5 p-1">
            {modes.map(({ id, title }) => (
              <button
                key={id}
                role="tab"
                aria-selected={id === selected}
                onClick={() => setSelected(id)}
                className={`rounded-full px-4 py-1.5 text-sm font-medium transition ${
                  id === selected ? "bg-white/15 text-white" : "text-white/55 hover:text-white"
                }`}
              >
                {title}
              </button>
            ))}
          </div>
          <Glass className="mt-6 max-w-md p-5">
            <p className="leading-relaxed text-white/70">{mode.text}</p>
          </Glass>
        </div>
        <div className="relative mx-auto w-full max-w-sm">
          <div aria-hidden="true" className="absolute inset-10 rounded-full bg-accent/20 blur-3xl" />
          {modes.map(({ id, title, screenshot }) => (
            <img
              key={id}
              src={`/screenshots/${screenshot}`}
              alt={`Walter's panel in ${title} mode`}
              className={`w-full transition-opacity duration-300 ${
                id === selected ? "relative opacity-100" : "absolute inset-x-0 top-0 opacity-0"
              }`}
            />
          ))}
        </div>
      </div>
    </section>
  );
}

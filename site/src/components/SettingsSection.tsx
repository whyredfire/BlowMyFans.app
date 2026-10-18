import { Check } from "lucide-react";
import { SectionHeading } from "./Features.tsx";

const options = [
  "Launch at login",
  "Celsius or Fahrenheit",
  "Choose what the menu bar shows: the hottest CPU, any sensor, or just the icon",
  "Let Manual mode stop the fans while your Mac is idle",
  "Install or remove the fan helper",
  "Signed updates that install themselves, without stealing focus",
];

export function SettingsSection() {
  return (
    <section className="mx-auto max-w-6xl px-6 py-24">
      <div className="grid items-center gap-14 lg:grid-cols-2">
        <div className="relative order-last mx-auto w-full max-w-md lg:order-first">
          <div aria-hidden="true" className="absolute inset-12 rounded-full bg-sky-500/15 blur-3xl" />
          <img src="/screenshots/settings.png" alt="Walter's Settings window" className="relative w-full" />
        </div>
        <div>
          <SectionHeading
            eyebrow="Settings"
            title="A few settings, all in one place."
            text="Walter is meant to be set once and forgotten. The options it does have fit on one screen."
          />
          <ul className="mt-8 space-y-3">
            {options.map((option) => (
              <li key={option} className="flex gap-3 text-white/70">
                <Check className="mt-0.5 size-5 shrink-0 text-accent-soft" />
                {option}
              </li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  );
}

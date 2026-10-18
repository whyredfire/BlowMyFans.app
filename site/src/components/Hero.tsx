import { Download } from "lucide-react";
import { downloadURL, repositoryURL } from "../links.ts";
import { GitHubIcon } from "./GitHubIcon.tsx";

export function Hero() {
  return (
    <section id="top" className="relative mx-auto grid max-w-6xl items-center gap-14 px-6 pt-20 pb-24 lg:grid-cols-[1.05fr_1fr] lg:pt-28">
      <div>
        <p className="mb-6 inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-3 py-1 text-xs text-white/70">
          <span className="size-1.5 rounded-full bg-emerald-400" />
          A native menu bar app for Apple silicon Macs
        </p>
        <h1 className="text-5xl font-semibold tracking-tight text-balance text-white sm:text-6xl">
          Keep your Mac cool, <span className="text-accent-soft">on your terms.</span>
        </h1>
        <p className="mt-6 max-w-xl text-lg leading-relaxed text-pretty text-white/60">
          Walter is a small, native menu bar app that shows your Mac's temperatures and puts you in charge of its
          fans. Let macOS decide, pick a speed, draw your own curve, or go Full Blast.
        </p>
        <div className="mt-9 flex flex-wrap items-center gap-3">
          <a
            href={downloadURL}
            className="flex items-center gap-2 rounded-full bg-white px-5 py-2.5 font-medium text-black transition hover:bg-white/85"
          >
            <Download className="size-4.5" />
            Download for Mac
          </a>
          <a
            href={repositoryURL}
            className="flex items-center gap-2 rounded-full border border-white/15 bg-white/5 px-5 py-2.5 font-medium text-white/85 transition hover:bg-white/10"
          >
            <GitHubIcon className="size-4.5" />
            View on GitHub
          </a>
        </div>
      </div>

      <div className="relative mx-auto w-full max-w-sm lg:max-w-md">
        <div aria-hidden="true" className="absolute inset-x-8 top-24 bottom-10 rounded-full bg-accent/30 blur-3xl" />
        <img
          src="/screenshots/panel-curve.png"
          alt="Walter's menu bar panel in Curve mode, showing the fan curve, fan speeds and temperatures"
          width={772}
          height={1232}
          className="relative w-full"
        />
      </div>
    </section>
  );
}


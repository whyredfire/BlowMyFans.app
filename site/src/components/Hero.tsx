import { brewCommands } from "../links.ts";
import { CopyCommand } from "./CopyCommand.tsx";

export function Hero() {
  return (
    <section id="top" className="mx-auto max-w-5xl px-6 pt-16 sm:pt-24">
      <div className="mx-auto flex max-w-2xl flex-col items-center text-center">
        <img src="/icon.png" alt="" width={112} height={112} className="size-24 sm:size-28" />
        <h1 className="mt-8 text-4xl font-semibold tracking-[-0.03em] text-balance text-white sm:text-6xl">
          Fan control for your Mac.
        </h1>
        <p className="mt-5 max-w-xl text-lg leading-relaxed text-pretty text-neutral-400">
          A small menu bar app that shows your Mac's temperatures and puts you in charge of its fans.
        </p>
        <CopyCommand commands={brewCommands} className="mt-10 w-full max-w-xl text-left" />
        <p className="mt-4 text-sm text-neutral-500">
          or{" "}
          <a href="#download" className="text-neutral-300 underline decoration-neutral-600 underline-offset-4 transition-colors hover:text-white">
            download the app
          </a>{" "}
          · Apple silicon, macOS 26 or later
        </p>
      </div>
      <Desktop />
    </section>
  );
}

/** The panel as it appears on screen, over a wallpaper. */
function Desktop() {
  return (
    <div className="relative mt-16 overflow-hidden rounded-2xl border border-white/10 sm:mt-20 sm:rounded-3xl">
      <div
        aria-hidden="true"
        className="absolute inset-0"
        style={{
          background:
            "radial-gradient(120% 90% at 15% 0%, #4c5fd7 0%, transparent 55%), radial-gradient(90% 80% at 100% 100%, #b04aa8 0%, transparent 60%), linear-gradient(160deg, #1d2257 0%, #2a1c4a 55%, #120f24 100%)",
        }}
      />
      <div className="relative flex justify-center px-4 py-8 sm:justify-end sm:px-16 sm:py-12">
        <img
          src="/screenshots/panel-curve.png"
          alt="Walter's panel in Curve mode, with the fan curve, fan speeds and temperatures"
          width={680}
          height={1140}
          className="w-[280px] rounded-[22px] drop-shadow-2xl sm:w-[340px]"
        />
      </div>
    </div>
  );
}

import { downloadURL, quarantineCommand } from "../links.ts";
import { CopyCommand } from "./CopyCommand.tsx";

/** The manual route; the Homebrew command lives in the hero. */
export function Download() {
  return (
    <section id="download" className="mx-auto max-w-5xl scroll-mt-8 px-6 py-32">
      <div className="max-w-2xl">
        <h2 className="text-3xl font-semibold tracking-[-0.02em] text-white sm:text-4xl">Not using Homebrew?</h2>
        <p className="mt-5 leading-relaxed text-pretty text-neutral-400">
          <a href={downloadURL} className="text-neutral-200 underline decoration-neutral-600 underline-offset-4 transition-colors hover:text-white">
            Download Walter
          </a>
          , unzip it and move it to Applications. It isn't notarized yet, so allow it once in System Settings › Privacy
          & Security, or run:
        </p>
        <CopyCommand commands={[quarantineCommand]} className="mt-5" />
      </div>
    </section>
  );
}

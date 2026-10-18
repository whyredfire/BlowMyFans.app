import { Check, Copy, Download } from "lucide-react";
import { useState, type ReactNode } from "react";
import { brewCommands, downloadURL, quarantineCommand } from "../links.ts";
import { SectionHeading } from "./Features.tsx";
import { Glass } from "./Glass.tsx";

export function Install() {
  return (
    <section id="install" className="mx-auto max-w-6xl scroll-mt-20 px-6 py-24">
      <SectionHeading
        eyebrow="Install"
        title="Up and running in a minute."
        text="Walter needs an Apple silicon Mac with macOS 26 or later. Once it's installed, it keeps itself up to date."
      />
      <Glass className="mt-12 p-6">
        <h3 className="font-semibold text-white">With Homebrew</h3>
        <p className="mt-1 text-sm text-white/55">Installs Walter and allows it to open, in one go. Then continue with step 3.</p>
        <CopyCommand command={brewCommands.join("\n")} />
      </Glass>
      <p className="mt-10 text-sm font-medium text-white/45">Or by hand</p>
      <ol className="mt-4 grid gap-4 lg:grid-cols-3">
        <Step number={1} title="Download">
          <p>
            Download <code className="text-white/80">Walter.zip</code>, unzip it and move Walter to your Applications
            folder.
          </p>
          <a
            href={downloadURL}
            className="mt-5 inline-flex items-center gap-2 rounded-full bg-white px-4 py-2 text-sm font-medium text-black transition hover:bg-white/85"
          >
            <Download className="size-4" />
            Download Walter
          </a>
        </Step>
        <Step number={2} title="Allow it once">
          <p>
            Walter isn't notarized by Apple yet, so macOS blocks it the first time. Clear the block from Terminal, or
            choose Open Anyway in System Settings › Privacy & Security.
          </p>
          <CopyCommand command={quarantineCommand} />
        </Step>
        <Step number={3} title="Take control">
          <p>
            Open Walter from the menu bar. The first time you choose a mode other than Auto, it installs a small helper
            that changes fan speeds, and asks for your administrator password.
          </p>
        </Step>
      </ol>
    </section>
  );
}

function Step({ number, title, children }: { number: number; title: string; children: ReactNode }) {
  return (
    <li>
      <Glass className="h-full p-6 text-sm leading-relaxed text-white/55">
        <span className="flex size-8 items-center justify-center rounded-full bg-accent/15 font-semibold text-accent-soft">
          {number}
        </span>
        <h3 className="mt-5 mb-2 text-base font-semibold text-white">{title}</h3>
        {children}
      </Glass>
    </li>
  );
}

function CopyCommand({ command }: { command: string }) {
  const [copied, setCopied] = useState(false);

  async function copy() {
    await navigator.clipboard.writeText(command);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  }

  return (
    <div className="mt-5 flex items-center gap-2 rounded-xl border border-white/10 bg-black/40 py-2 pr-2 pl-3 font-mono text-xs text-white/75">
      <code className="min-w-0 flex-1 whitespace-pre-wrap wrap-break-word">{command}</code>
      <button
        onClick={copy}
        aria-label={copied ? "Copied" : "Copy command"}
        className="rounded-lg p-1.5 text-white/60 transition hover:bg-white/10 hover:text-white"
      >
        {copied ? <Check className="size-4 text-emerald-400" /> : <Copy className="size-4" />}
      </button>
    </div>
  );
}

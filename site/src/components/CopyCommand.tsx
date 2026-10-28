import { Check, Copy } from "lucide-react";
import { useState } from "react";

/** Terminal commands with a copy button; `$` prompts are shown but not copied. */
export function CopyCommand({ commands, className = "" }: { commands: readonly string[]; className?: string }) {
  const [copied, setCopied] = useState(false);

  async function copy() {
    try {
      await navigator.clipboard.writeText(commands.join("\n"));
    } catch {
      // Clipboard access was denied; the commands can still be selected and copied by hand.
      return;
    }
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  }

  return (
    <div
      className={`flex items-center gap-2 rounded-xl border border-white/10 bg-black/40 py-2 pr-2 pl-3 font-mono text-xs text-white/75 ${className}`}
    >
      <code className="min-w-0 flex-1 overflow-x-auto whitespace-pre [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
        {commands.map((command) => (
          <span key={command} className="block">
            <span aria-hidden="true" className="text-white/30 select-none">$ </span>
            {command}
          </span>
        ))}
      </code>
      <button
        onClick={copy}
        aria-label={copied ? "Copied" : "Copy commands"}
        className="self-start rounded-lg p-1.5 text-white/60 transition hover:bg-white/10 hover:text-white"
      >
        {copied ? <Check className="size-4 text-emerald-400" /> : <Copy className="size-4" />}
      </button>
    </div>
  );
}

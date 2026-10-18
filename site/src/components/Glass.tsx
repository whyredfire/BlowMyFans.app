import type { ReactNode } from "react";

/** A translucent card in the style of macOS Liquid Glass. */
export function Glass({ className = "", children }: { className?: string; children: ReactNode }) {
  return (
    <div
      className={`rounded-3xl border border-white/10 bg-white/[0.04] shadow-[inset_0_1px_0_rgb(255_255_255/0.08)] backdrop-blur-xl ${className}`}
    >
      {children}
    </div>
  );
}

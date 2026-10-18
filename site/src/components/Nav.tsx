import { Download } from "lucide-react";
import { downloadURL, repositoryURL } from "../links.ts";
import { GitHubIcon } from "./GitHubIcon.tsx";

export function Nav() {
  return (
    <header className="sticky top-0 z-20 border-b border-white/5 bg-[#08080c]/70 backdrop-blur-xl">
      <nav className="mx-auto flex h-14 max-w-6xl items-center gap-6 px-6">
        <a href="#top" className="flex items-center gap-2.5 font-semibold tracking-tight">
          <img src="/icon.png" alt="" className="size-7" />
          Walter
        </a>
        <div className="ml-auto hidden items-center gap-6 text-sm text-white/60 sm:flex">
          <a href="#features" className="transition hover:text-white">Features</a>
          <a href="#modes" className="transition hover:text-white">Modes</a>
          <a href="#install" className="transition hover:text-white">Install</a>
        </div>
        <a href={repositoryURL} aria-label="Walter on GitHub" className="ml-auto text-white/60 transition hover:text-white sm:ml-0">
          <GitHubIcon className="size-5" />
        </a>
        <a
          href={downloadURL}
          className="flex items-center gap-1.5 rounded-full bg-white px-3.5 py-1.5 text-sm font-medium text-black transition hover:bg-white/85"
        >
          <Download className="size-4" />
          Download
        </a>
      </nav>
    </header>
  );
}

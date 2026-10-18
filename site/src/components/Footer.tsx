import { releasesURL, repositoryURL } from "../links.ts";

export function Footer() {
  return (
    <footer className="border-t border-white/5">
      <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-4 px-6 py-10 text-sm text-white/45 sm:flex-row">
        <div className="flex items-center gap-2.5">
          <img src="/icon.png" alt="" className="size-6" />
          <span>
            Walter, by <a href="https://whyredfire.dev" className="text-white/70 transition hover:text-white">whyredfire</a>
          </span>
        </div>
        <div className="flex gap-6">
          <a href={repositoryURL} className="transition hover:text-white">Source</a>
          <a href={releasesURL} className="transition hover:text-white">Releases</a>
        </div>
      </div>
    </footer>
  );
}

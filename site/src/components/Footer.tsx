import { releasesURL, repositoryURL, translateURL } from "../links.ts";

export function Footer() {
  return (
    <footer className="mx-auto max-w-5xl px-6">
      <div className="flex flex-col gap-3 border-t border-white/10 py-8 text-sm text-neutral-500 sm:flex-row sm:justify-between">
      <p>
        Blow My Fans by{" "}
        <a href="https://whyredfire.dev" className="text-neutral-300 transition-colors hover:text-white">
          whyredfire
        </a>
      </p>
      <div className="flex gap-6">
        <a href={repositoryURL} className="transition-colors hover:text-white">Source</a>
        <a href={releasesURL} className="transition-colors hover:text-white">Releases</a>
        <a href={`${repositoryURL}/issues`} className="transition-colors hover:text-white">Feedback</a>
        <a href={translateURL} className="transition-colors hover:text-white">Translate</a>
      </div>
      </div>
    </footer>
  );
}

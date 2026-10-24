import { repositoryURL } from "../links.ts";

export function Header() {
  return (
    <header className="mx-auto flex max-w-5xl items-center justify-between px-6 py-6">
      <a href="#top" className="flex items-center gap-2 text-[15px] font-semibold tracking-tight text-white">
        <img src="/icon.png" alt="" className="size-6" />
        Blow My Fans
      </a>
      <nav className="flex items-center gap-7 text-sm text-neutral-400">
        <a href="#modes" className="hidden transition-colors hover:text-white sm:block">Modes</a>
        <a href="#changelog" className="hidden transition-colors hover:text-white sm:block">Changelog</a>
        <a href={repositoryURL} className="transition-colors hover:text-white">GitHub</a>
      </nav>
    </header>
  );
}

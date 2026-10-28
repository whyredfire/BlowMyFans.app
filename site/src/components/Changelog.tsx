import { useEffect, useState } from "react";
import { releasesURL } from "../links.ts";
import { fetchReleases, type ChangeKind, type Release } from "../releases.ts";

const shownReleases = 3;
const groups: { kind: ChangeKind; title: string }[] = [
  { kind: "new", title: "New" },
  { kind: "improved", title: "Improved" },
  { kind: "fixed", title: "Fixed" },
];
const dateFormat = new Intl.DateTimeFormat("en", { month: "long", day: "numeric", year: "numeric" });

/** The latest releases, read from GitHub so the page never needs updating for one. */
export function Changelog() {
  const [releases, setReleases] = useState<Release[] | "unavailable" | null>(null);

  useEffect(() => {
    fetchReleases(shownReleases).then(setReleases, () => setReleases("unavailable"));
  }, []);

  return (
    <section id="changelog" className="mx-auto max-w-5xl scroll-mt-8 px-6 pt-32">
      <div className="flex items-baseline justify-between gap-6">
        <h2 className="text-3xl font-semibold tracking-[-0.02em] text-white sm:text-4xl">What's new.</h2>
        <a href={releasesURL} className="shrink-0 text-sm text-neutral-400 transition-colors hover:text-white">
          All releases →
        </a>
      </div>

      {releases === "unavailable" && (
        <p className="mt-8 text-neutral-400">
          The changelog couldn't be loaded.{" "}
          <a href={releasesURL} className="text-neutral-200 underline decoration-neutral-600 underline-offset-4 hover:text-white">
            See the releases on GitHub
          </a>
          .
        </p>
      )}

      {Array.isArray(releases) && (
        <ol className="mt-12">
          {releases.map((release) => (
            <li key={release.version} className="grid gap-4 border-t border-white/10 py-8 sm:grid-cols-[10rem_1fr]">
              <div>
                <a href={release.url} className="font-medium text-white transition-colors hover:text-neutral-300">
                  {release.version}
                </a>
                <p className="mt-1 text-sm text-neutral-500">
                  <time dateTime={release.date.toISOString()}>{dateFormat.format(release.date)}</time>
                </p>
              </div>
              {release.changes.length === 0 ? (
                <p className="text-neutral-400">Behind-the-scenes improvements.</p>
              ) : (
                <div className="space-y-5">
                  {groups.map(({ kind, title }) => {
                    const changes = release.changes.filter((change) => change.kind === kind);
                    if (changes.length === 0) return null;
                    return (
                      <div key={kind}>
                        <h3 className="text-sm font-medium text-neutral-500">{title}</h3>
                        <ul className="mt-2 space-y-1.5 leading-relaxed text-neutral-300">
                          {changes.map((change, index) => (
                            // Two commits can share a subject, so the position keeps keys unique.
                            <li key={index}>{change.text}</li>
                          ))}
                        </ul>
                      </div>
                    );
                  })}
                </div>
              )}
            </li>
          ))}
        </ol>
      )}
    </section>
  );
}

import { repositoryURL } from "./links.ts";

export type ChangeKind = "new" | "fixed" | "improved";
export type Change = { kind: ChangeKind; text: string };
export type Release = { version: string; date: Date; url: string; changes: Change[] };

const headings: Record<string, ChangeKind> = { New: "new", Improved: "improved", Fixed: "fixed" };

/** Reads the "## New", "## Improved" and "## Fixed" lists that scripts/changelog.sh writes into release notes. */
export function parseChanges(notes: string): Change[] {
  let kind: ChangeKind | undefined;
  return notes.split("\n").flatMap((line) => {
    const heading = /^#+ (.+)$/.exec(line.trim());
    if (heading) {
      kind = headings[heading[1]!.trim()];
      return [];
    }
    const item = /^[-*] (.+)$/.exec(line.trim());
    return kind && item ? [{ kind, text: item[1]! }] : [];
  });
}

type GitHubRelease = {
  tag_name: string;
  html_url: string;
  published_at: string;
  body: string | null;
  draft: boolean;
  prerelease: boolean;
};

export async function fetchReleases(count: number): Promise<Release[]> {
  const api = repositoryURL.replace("https://github.com/", "https://api.github.com/repos/");
  const response = await fetch(`${api}/releases?per_page=${count}`, {
    headers: { Accept: "application/vnd.github+json" },
  });
  if (!response.ok) throw new Error(`GitHub answered ${response.status}`);
  const releases = (await response.json()) as GitHubRelease[];
  return releases
    .filter((release) => !release.draft && !release.prerelease)
    .map((release) => ({
      version: release.tag_name.replace(/^v/, ""),
      date: new Date(release.published_at),
      url: release.html_url,
      changes: parseChanges(release.body ?? ""),
    }));
}

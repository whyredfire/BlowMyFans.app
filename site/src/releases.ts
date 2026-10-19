import { repositoryURL } from "./links.ts";

export type ChangeKind = "new" | "fixed" | "improved";
export type Change = { kind: ChangeKind; text: string };
export type Release = { version: string; date: Date; url: string; changes: Change[] };

/** Commit types that matter to people using Walter; everything else is left out. */
const kinds: Record<string, ChangeKind> = { feat: "new", fix: "fixed", perf: "improved" };
/** Scopes about the project rather than the app. */
const hiddenScopes = new Set(["site", "ci"]);

/** Turns release notes like "- fix(curve): Stop the fans … (9c44c4d)" into user-facing changes. */
export function parseChanges(notes: string): Change[] {
  return notes.split("\n").flatMap((line) => {
    const match = /^[-*] (\w+)(?:\(([^)]+)\))?!?: (.+?)(?: \([0-9a-f]{7,}\))?$/.exec(line.trim());
    if (!match) return [];
    const [, type, scope, text] = match;
    const kind = kinds[type!];
    if (!kind || (scope && hiddenScopes.has(scope))) return [];
    return [{ kind, text: text!.charAt(0).toUpperCase() + text!.slice(1) }];
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

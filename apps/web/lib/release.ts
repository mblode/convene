import { fallbackVersion, siteConfig } from "./config";

interface GitHubAsset {
  browser_download_url: string;
  name: string;
  size: number;
}

interface GitHubRelease {
  assets: GitHubAsset[];
  published_at: string;
  tag_name: string;
}

export interface Release {
  downloadUrl: string;
  fileSize: string;
  /** Null when we could not confirm a real date — better to omit the freshness
   * line than to print one that is wrong. */
  publishedRelative: string | null;
  version: string;
}

const relativeDays = (isoDate: string): string | null => {
  const published = new Date(isoDate).getTime();
  if (Number.isNaN(published)) {
    return null;
  }
  const days = Math.floor((Date.now() - published) / 86_400_000);
  if (days < 0) {
    return null;
  }
  if (days === 0) {
    return "updated today";
  }
  if (days === 1) {
    return "updated yesterday";
  }
  if (days < 45) {
    return `updated ${days} days ago`;
  }
  const months = Math.round(days / 30);
  return `updated ${months} month${months === 1 ? "" : "s"} ago`;
};

/** The unauthenticated GitHub API allows 60 requests/hour/IP, so a cold cache
 * on a busy host will miss. When it does, fall back to the real shipped
 * version rather than a placeholder, and drop the freshness line entirely. */
export const getLatestRelease = async (): Promise<Release> => {
  const fallback: Release = {
    downloadUrl: `${siteConfig.links.releases}/latest`,
    fileSize: "",
    publishedRelative: null,
    version: fallbackVersion,
  };

  try {
    const res = await fetch(
      "https://api.github.com/repos/mblode/convene/releases/latest",
      {
        next: { revalidate: 3600 },
      }
    );
    if (!res.ok) {
      return fallback;
    }
    const release = (await res.json()) as GitHubRelease;
    const dmg = release.assets?.find((asset) => asset.name.endsWith(".dmg"));

    return {
      downloadUrl: dmg?.browser_download_url ?? fallback.downloadUrl,
      fileSize: dmg ? `${(dmg.size / 1024 / 1024).toFixed(1)} MB` : "",
      publishedRelative: release.published_at
        ? relativeDays(release.published_at)
        : null,
      version: release.tag_name || fallbackVersion,
    };
  } catch {
    return fallback;
  }
};

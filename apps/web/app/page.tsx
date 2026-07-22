import Image from "next/image";

import { SiteFooter } from "@/components/site-footer";

interface GitHubAsset {
  name: string;
  size: number;
  browser_download_url: string;
}

interface GitHubRelease {
  tag_name: string;
  assets: GitHubAsset[];
}

const FEATURES = [
  "Records both sides of a call: your mic and the other side's audio",
  "Transcribes live while the meeting runs, split by speaker",
  "Saves a Markdown note when you stop, with an AI summary and the full transcript",
  "Puts today's calendar in the menu bar. Click an event to join it and start recording",
  "Notices Zoom, Teams, Webex, Meet, and BlueJeans opening, and offers to record",
  "Keys stay in your Keychain, notes stay in your folder. There's no Convene server",
] as const;

const getLatestRelease = async (): Promise<{
  downloadUrl: string;
  fileSizeMB: string;
  version: string;
}> => {
  try {
    const res = await fetch(
      "https://api.github.com/repos/mblode/convene/releases/latest",
      { next: { revalidate: 3600 } }
    );
    if (!res.ok) {
      throw new Error("Failed to fetch release");
    }
    const release: GitHubRelease = await res.json();
    const dmg = release.assets.find((a) => a.name.endsWith(".dmg"));
    return {
      downloadUrl: dmg?.browser_download_url ?? "#",
      fileSizeMB: dmg ? `${(dmg.size / 1024 / 1024).toFixed(1)} MB` : "",
      version: release.tag_name ?? "v0.1.0",
    };
  } catch {
    return {
      downloadUrl: "https://github.com/mblode/convene/releases/latest",
      fileSizeMB: "",
      version: "v0.1.0",
    };
  }
};

export default async function Page() {
  const { downloadUrl, fileSizeMB, version } = await getLatestRelease();

  return (
    <div className="flex min-h-dvh flex-col bg-twilight-ink">
      <main
        className="relative flex flex-1 flex-col items-center justify-center px-6 py-32 text-center"
        style={{ background: "var(--gradient-sky)" }}
      >
        <Image
          alt="Convene"
          className="rounded-[22%] shadow-[0_24px_60px_-20px_rgba(0,0,0,0.45)]"
          height={80}
          priority
          src="/app-icon.png"
          width={80}
        />

        <h1 className="mt-7 font-normal text-display text-polar-white">
          Convene
        </h1>

        <p className="mt-3 text-polar-white/85 text-subheading">
          An open-source Granola clone for macOS.
        </p>

        <p className="mt-5 max-w-md text-body text-polar-white/75">
          Records your meetings, transcribes them live, and writes the notes
          into a folder you own.
        </p>

        <div className="mt-7 inline-flex items-center gap-3">
          <a
            className="inline-flex items-center gap-2 rounded-lg border border-white/[0.06] bg-white/[0.08] px-4 py-2.5 text-[14px] text-white/95 tracking-[-0.1px] backdrop-blur-sm transition-colors hover:bg-white/[0.14] active:bg-white/[0.18]"
            href={downloadUrl}
          >
            <svg
              aria-hidden="true"
              fill="currentColor"
              height="14"
              style={{ position: "relative", top: "-1px" }}
              viewBox="0 0 814 1000"
              width="12"
            >
              <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76.5 0-103.7 40.8-165.9 40.8s-105.6-57.8-155.5-127.4c-58.3-81.8-105.3-209.2-105.3-330.3 0-194.3 126.4-297.5 250.8-297.5 66.1 0 121.2 43.4 162.7 43.4 39.5 0 101.1-46 176.3-46 28.5 0 130.9 2.6 198.3 99.2zm-234-181.5c31.1-36.9 53.1-88.1 53.1-139.3 0-7.1-.6-14.3-1.9-20.1-50.6 1.9-110.8 33.7-147.1 75.8-28.5 32.4-55.1 83.6-55.1 135.5 0 7.8.6 15.7 1.3 18.2 2.6.6 6.4 1.3 10.2 1.3 45.4 0 103.5-30.4 139.5-71.4z" />
            </svg>
            Download for macOS
          </a>
          {fileSizeMB && (
            <span className="text-caption text-white/60">{fileSizeMB}</span>
          )}
        </div>

        <span className="mt-3 text-caption text-white/60">
          {version} · Requires macOS 15
        </span>
      </main>

      <section className="border-charcoal-black border-t bg-twilight-ink px-6 py-20">
        <div className="mx-auto max-w-2xl">
          <h2 className="text-center text-pewter-mist text-subheading">
            What it does
          </h2>
          <ul className="mt-8 flex flex-col gap-4">
            {FEATURES.map((feature) => (
              <li
                className="flex items-start gap-3 text-body text-silver-tone"
                key={feature}
              >
                <span
                  aria-hidden="true"
                  className="mt-2 size-1.5 shrink-0 rounded-full bg-cerulean-accent"
                />
                {feature}
              </li>
            ))}
          </ul>
        </div>
      </section>

      <SiteFooter />
    </div>
  );
}

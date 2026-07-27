import { siteConfig } from "@/lib/config";

export const SiteFooter = () => (
  <footer className="border-t border-charcoal-black bg-twilight-ink">
    <div className="mx-auto flex max-w-5xl flex-col items-center justify-center gap-2 px-6 py-12 text-caption">
      <div className="flex items-center gap-1 text-pewter-mist">
        Crafted by
        <a
          className="flex items-center gap-2 rounded-full py-1.5 pr-2.5 pl-1.5 text-pewter-mist transition-colors hover:text-polar-white"
          href={siteConfig.links.author}
          rel="author noopener noreferrer"
          target="_blank"
        >
          {/* biome-ignore lint/performance/noImgElement: self-hosted 20px avatar, plain img avoids next/image overhead */}
          {/* oxlint-disable-next-line nextjs/no-img-element -- self-hosted 20px avatar, plain img avoids next/image overhead */}
          <img
            alt="Avatar of Matthew Blode"
            className="rounded-full"
            height={20}
            loading="lazy"
            src="/convene/avatar-sm.png"
            width={20}
          />
          Matthew Blode
        </a>
      </div>
      <div className="flex items-center gap-2 text-obsidian-grey">
        <a
          className="text-pewter-mist transition-colors hover:text-cerulean-accent"
          href={siteConfig.links.github}
          rel="noopener noreferrer"
          target="_blank"
        >
          GitHub
        </a>
      </div>
    </div>
  </footer>
);

import Image from "next/image";

import { siteConfig } from "@/lib/config";

export const SiteFooter = () => (
  <footer className="border-t border-charcoal-black bg-twilight-ink">
    <div className="mx-auto flex max-w-5xl flex-col items-center justify-center gap-2 px-6 py-12 text-caption">
      <div className="flex items-center gap-1 text-pewter-mist">
        Crafted by
        <a
          className="flex items-center gap-2 rounded-full py-1.5 pr-2.5 pl-1.5 text-pewter-mist transition-colors hover:text-polar-white"
          href={siteConfig.links.author}
          rel="noopener noreferrer"
          target="_blank"
        >
          <Image
            alt="Avatar of Matthew Blode"
            className="rounded-full"
            height={20}
            src="/matthew-blode-profile.jpg"
            unoptimized
            width={20}
          />
          Matthew Blode
        </a>
      </div>
      <div className="flex items-center gap-2 text-obsidian-grey">
        <span className="text-pewter-mist">v{siteConfig.version}</span>
        <span aria-hidden="true">·</span>
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

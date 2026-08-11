import type { MetadataRoute } from "next";

import { siteConfig } from "@/lib/config";
import { GRANOLA_UPDATED, OBSIDIAN_UPDATED, PAGE_UPDATED } from "@/lib/landing";

// Next does not prefix basePath onto sitemap URLs, so every entry is built from
// siteConfig.url, which already carries /convene.
//
// Literal dates, not new Date(): the sitemap is statically generated at build
// time, and a build clock would claim every page changed on every deploy.
//
// One constant per page rather than one shared across all three — see the
// docblock in lib/landing.ts for why that distinction is load-bearing. The home
// page's constant is the same one feeding `WebPage.dateModified`, so the
// sitemap and the graph cannot disagree about when this page last changed.
export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      changeFrequency: "monthly",
      lastModified: PAGE_UPDATED,
      priority: 1,
      url: siteConfig.url,
    },
    {
      changeFrequency: "monthly",
      lastModified: GRANOLA_UPDATED,
      priority: 0.8,
      url: `${siteConfig.url}/granola-alternative`,
    },
    {
      changeFrequency: "monthly",
      lastModified: OBSIDIAN_UPDATED,
      priority: 0.8,
      url: `${siteConfig.url}/obsidian-meeting-notes`,
    },
  ];
}

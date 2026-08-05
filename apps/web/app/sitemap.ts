import type { MetadataRoute } from "next";

import { siteConfig } from "@/lib/config";

// Next does not prefix basePath onto sitemap URLs, so every entry is built from
// siteConfig.url, which already carries /convene.
//
// A literal date, not new Date(): the sitemap is statically generated at build
// time, and a build clock would claim every page changed on every deploy.
const lastModified = "2026-08-05";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      changeFrequency: "monthly",
      lastModified,
      priority: 1,
      url: siteConfig.url,
    },
    {
      changeFrequency: "monthly",
      lastModified,
      priority: 0.8,
      url: `${siteConfig.url}/granola-alternative`,
    },
    {
      changeFrequency: "monthly",
      lastModified,
      priority: 0.8,
      url: `${siteConfig.url}/obsidian-meeting-notes`,
    },
  ];
}

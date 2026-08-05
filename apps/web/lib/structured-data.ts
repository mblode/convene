import { siteConfig } from "@/lib/config";

/** The repo has no LICENSE file — the README's License section states MIT. */
const licenseUrl = `${siteConfig.links.github}#license`;

export const softwareApplicationSchema = () => ({
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  applicationCategory: "BusinessApplication",
  description: siteConfig.description,
  isAccessibleForFree: true,
  license: licenseUrl,
  name: siteConfig.name,
  offers: {
    "@type": "Offer",
    price: "0",
    priceCurrency: "USD",
  },
  operatingSystem: "macOS 15, iOS 17",
  sameAs: siteConfig.links.github,
  url: siteConfig.url,
});

export const webSiteSchema = () => ({
  "@context": "https://schema.org",
  "@type": "WebSite",
  description: siteConfig.description,
  name: siteConfig.name,
  url: siteConfig.url,
});

export const faqPageSchema = (
  items: { answer: string; question: string }[]
) => ({
  "@context": "https://schema.org",
  "@type": "FAQPage",
  mainEntity: items.map((item) => ({
    "@type": "Question",
    acceptedAnswer: {
      "@type": "Answer",
      text: item.answer,
    },
    name: item.question,
  })),
});

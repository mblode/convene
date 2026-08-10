import { siteConfig } from "@/lib/config";

const licenseUrl = `${siteConfig.links.github}/blob/main/LICENSE.md`;

const siteUrl = siteConfig.url;

/** The host graph. blode.co owns exactly one Person, one WebSite and one
 * Organization; this zone is the same origin behind a rewrite, so it references
 * them by @id and never redefines their bodies. A zone-scoped #website would
 * publish a second site on the same domain. See
 * blode-co/apps/web/.claude/knowledge/zone-conventions.md, rule 2. */
const personId = "https://blode.co/#person";
const websiteId = "https://blode.co/#website";
const organizationId = "https://blode.co/#organization";

/** Zone-local nodes keep the zone in the id. Note the slash before the hash. */
const webPageId = `${siteUrl}/#webpage`;
const softwareId = `${siteUrl}/#software`;
const breadcrumbId = `${siteUrl}/#breadcrumb`;

/** SoftwareApplication, not SoftwareSourceCode: the page sells a signed binary
 * you download and run, not a repository you read. `offers` is honest — the
 * closing CTA says "Free, MIT licensed, no account" — and there is deliberately
 * no aggregateRating, because self-authored ratings breach Google's guidelines.
 * Without one the software rich result will not trigger; that is the correct
 * outcome for an app with no third-party reviews. */
const softwareApplicationNode = {
  "@id": softwareId,
  "@type": "SoftwareApplication",
  applicationCategory: "BusinessApplication",
  author: { "@id": personId },
  description: siteConfig.description,
  image: `${siteUrl}/opengraph-image`,
  isAccessibleForFree: true,
  license: licenseUrl,
  name: siteConfig.name,
  offers: {
    "@type": "Offer",
    availability: "https://schema.org/InStock",
    // Numeric 0 matches Google's SoftwareApplication example. String "0"
    // is schema.org-legal but Semrush Site Audit flags it as invalid markup.
    price: 0,
    priceCurrency: "USD",
  },
  operatingSystem: "macOS 15, iOS 17",
  /** publisher is the Organization: rich results expect one carrying a logo,
   * and a Person publisher is a standing Search Console warning. */
  publisher: { "@id": organizationId },
  sameAs: siteConfig.links.github,
  url: siteUrl,
};

/** The trail starts at the blode.co root, not at this zone. Beginning it at
 * https://blode.co/convene would tell Google the zone is its own site. */
const breadcrumbNode = {
  "@id": breadcrumbId,
  "@type": "BreadcrumbList",
  itemListElement: [
    {
      "@type": "ListItem",
      item: "https://blode.co/",
      name: "Matthew Blode",
      position: 1,
    },
    {
      "@type": "ListItem",
      item: "https://blode.co/projects",
      name: "Projects",
      position: 2,
    },
    {
      "@type": "ListItem",
      item: siteUrl,
      name: siteConfig.name,
      position: 3,
    },
  ],
};

const questionNodes = (items: { answer: string; question: string }[]) =>
  items.map((item) => ({
    "@type": "Question",
    acceptedAnswer: {
      "@type": "Answer",
      text: item.answer,
    },
    name: item.question,
  }));

/** One script, one @graph. Disconnected ld+json blocks cannot be merged into a
 * single entity by a crawler, so everything the home page asserts lives here. */
export const homePageSchema = (
  faqItems: { answer: string; question: string }[]
) => ({
  "@context": "https://schema.org",
  "@graph": [
    {
      "@id": webPageId,
      "@type": "WebPage",
      about: { "@id": softwareId },
      breadcrumb: { "@id": breadcrumbId },
      description: siteConfig.description,
      inLanguage: "en",
      isPartOf: { "@id": websiteId },
      name: siteConfig.name,
      url: siteUrl,
    },
    softwareApplicationNode,
    breadcrumbNode,
    // Separate FAQPage node (not dual-typed onto WebPage). Semrush and Google's
    // rich-result validators treat ["WebPage","FAQPage"] as invalid markup.
    {
      "@id": `${siteUrl}/#faq`,
      "@type": "FAQPage",
      inLanguage: "en",
      isPartOf: { "@id": websiteId },
      mainEntity: questionNodes(faqItems),
      name: `${siteConfig.name} questions`,
      url: siteUrl,
    },
  ],
});

export const faqPageSchema = (
  items: { answer: string; question: string }[]
) => ({
  "@context": "https://schema.org",
  "@type": "FAQPage",
  mainEntity: questionNodes(items),
});

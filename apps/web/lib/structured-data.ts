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
  isAccessibleForFree: true,
  license: licenseUrl,
  name: siteConfig.name,
  offers: {
    "@type": "Offer",
    price: "0",
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
      /** Also an FAQPage: the questions are the page's own main entity rather
       * than a second, disconnected document about the same URL. */
      "@type": ["WebPage", "FAQPage"],
      about: { "@id": softwareId },
      breadcrumb: { "@id": breadcrumbId },
      description: siteConfig.description,
      inLanguage: "en",
      isPartOf: { "@id": websiteId },
      mainEntity: questionNodes(faqItems),
      name: siteConfig.name,
      url: siteUrl,
    },
    softwareApplicationNode,
    breadcrumbNode,
  ],
});

export const faqPageSchema = (
  items: { answer: string; question: string }[]
) => ({
  "@context": "https://schema.org",
  "@type": "FAQPage",
  mainEntity: questionNodes(items),
});

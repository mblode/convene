import { siteConfig } from "@/lib/config";
import { PAGE_UPDATED } from "@/lib/landing";

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

export interface QuestionSource {
  answer: string;
  /** Anchor of the rendered `<h3>` on `pageUrl`. Published as
   * `acceptedAnswer.url`, so it has to resolve to a heading that exists and is
   * visible without opening anything. */
  id: string;
  question: string;
}

const questionNodes = (items: readonly QuestionSource[], pageUrl: string) =>
  items.map((item) => ({
    "@type": "Question",
    acceptedAnswer: {
      "@type": "Answer",
      text: item.answer,
      url: `${pageUrl}#${item.id}`,
    },
    name: item.question,
  }));

/** One script, one @graph. Disconnected ld+json blocks cannot be merged into a
 * single entity by a crawler, so everything the home page asserts lives here. */
export const homePageSchema = (faqItems: readonly QuestionSource[]) => ({
  "@context": "https://schema.org",
  "@graph": [
    {
      "@id": webPageId,
      "@type": "WebPage",
      about: { "@id": softwareId },
      breadcrumb: { "@id": breadcrumbId },
      /** Hand-maintained, from `lib/landing.ts`. A build clock here would claim
       * the page changed on every deploy, which is a freshness signal that
       * means nothing and gets discounted accordingly. */
      dateModified: PAGE_UPDATED,
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
      mainEntity: questionNodes(faqItems, siteUrl),
      name: `${siteConfig.name} questions`,
      url: siteUrl,
    },
  ],
});

/**
 * The graph for a long-form page under the zone.
 *
 * This replaced a bare `faqPageSchema()` — a lone `FAQPage` with no `@id`, no
 * `isPartOf` and no link to anything else on the site. That is the
 * disconnected-node shape the fleet rule exists to stop: a crawler cannot merge
 * a node that names no entity into the entity the rest of the site is about, so
 * the page published seven questions that belonged to nobody.
 *
 * Deliberately **no `BreadcrumbList`**, and that is the one thing here that
 * looks like an omission. These pages render no visible trail —
 * `components/shared/zone-breadcrumb.tsx` says root page only, and its third
 * constraint is that the visible trail and the `BreadcrumbList` must match
 * exactly, because Google treats a mismatch as a markup error. Declaring a
 * four-level trail that nothing on the page draws would trade one defect for a
 * different one. `isPartOf` and `about` are what connect the node, and they do.
 */
export const articlePageSchema = ({
  dateModified,
  description,
  items,
  name,
  slug,
}: {
  dateModified: string;
  description: string;
  items: readonly QuestionSource[];
  name: string;
  slug: string;
}) => {
  const pageUrl = `${siteUrl}/${slug}`;

  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@id": `${pageUrl}#webpage`,
        "@type": "WebPage",
        about: { "@id": softwareId },
        author: { "@id": personId },
        dateModified,
        description,
        inLanguage: "en",
        isPartOf: { "@id": websiteId },
        name,
        url: pageUrl,
      },
      {
        "@id": `${pageUrl}#faq`,
        "@type": "FAQPage",
        inLanguage: "en",
        isPartOf: { "@id": websiteId },
        mainEntity: questionNodes(items, pageUrl),
        name,
        url: pageUrl,
      },
    ],
  };
};

import { describe, expect, it } from "vitest";

import { FAQ } from "@/lib/faq";
import { articlePageSchema, homePageSchema } from "@/lib/structured-data";

/**
 * Structural rules for the `@graph`, each of which has broken somewhere in this
 * fleet before.
 *
 * The zone-redefinition one is the important one. Every zone under blode.co is a
 * path behind a rewrite, not a site of its own, so a `blode.co/convene/#person`
 * node publishes a second Matthew Blode on the same domain and splits the entity
 * every other zone is pointing at. The fleet auditor catches it after deploy;
 * this catches it before commit, which is several hours earlier and free.
 */

/** Spelled out rather than matched by regex: `tsconfig`'s target predates named
 * capture groups and the lint config requires them, so a regex with alternation
 * cannot satisfy both. A set of six strings is also easier to read. */
const ZONE_ENTITY_REDEFINITIONS = new Set(
  ["person", "website", "organization"].flatMap((entity) => [
    `https://blode.co/convene#${entity}`,
    `https://blode.co/convene/#${entity}`,
  ])
);

const ARTICLE_PAGES = [
  articlePageSchema({
    dateModified: "2026-08-05",
    description: "d",
    items: [{ answer: "a", id: "q", question: "q?" }],
    name: "n",
    slug: "granola-alternative",
  }),
  articlePageSchema({
    dateModified: "2026-08-05",
    description: "d",
    items: [{ answer: "a", id: "q", question: "q?" }],
    name: "n",
    slug: "obsidian-meeting-notes",
  }),
];

const GRAPHS = [homePageSchema(FAQ), ...ARTICLE_PAGES];

const ids = (graph: { "@graph": readonly { "@id"?: string }[] }) =>
  graph["@graph"].map((node) => node["@id"]).filter(Boolean) as string[];

/** blode.co owns Person, WebSite and Organization; a zone only ever points at
 * them. */
const ROOT_ENTITY_PREFIX = "https://blode.co/#";

/** Every `{"@id": …}` used as a value rather than to declare a node. */
const references = (nodes: readonly unknown[]): string[] => {
  const out: string[] = [];
  const walk = (value: unknown, isRoot: boolean) => {
    if (Array.isArray(value)) {
      for (const item of value) {
        walk(item, false);
      }
      return;
    }
    if (!value || typeof value !== "object") {
      return;
    }
    const record = value as Record<string, unknown>;
    for (const [key, child] of Object.entries(record)) {
      if (key === "@id") {
        if (!isRoot && typeof child === "string") {
          out.push(child);
        }
        continue;
      }
      walk(child, false);
    }
  };
  for (const node of nodes) {
    walk(node, true);
  }
  return out;
};

describe.each(
  GRAPHS.map((graph) => [graph["@graph"][0]["@id"], graph] as const)
)("the graph on %s", (_id, graph) => {
  it("gives every node a unique @id", () => {
    const seen = ids(graph);
    expect(seen).toHaveLength(graph["@graph"].length);
    expect(new Set(seen).size).toBe(seen.length);
  });

  it("never redefines a blode.co entity inside the zone", () => {
    // Person, WebSite and Organization belong to blode.co and are referenced
    // by @id from here, never declared. A zone-local copy of any of them forks
    // the entity across 33 sites.
    for (const id of ids(graph)) {
      expect(
        ZONE_ENTITY_REDEFINITIONS.has(id),
        `${id} redefines a blode.co-level entity`
      ).toBe(false);
    }
  });

  it("keeps zone-local ids inside the zone", () => {
    for (const id of ids(graph)) {
      expect(id.startsWith("https://blode.co/convene")).toBe(true);
    }
  });

  /**
   * The defect the two long-form pages shipped with: a bare `FAQPage`, no
   * `@id`, no `isPartOf`, connected to nothing. A crawler cannot merge a node
   * that names no entity into the entity the rest of the site is about, so
   * those pages published their questions on behalf of nobody.
   *
   * A reference resolves if it lands in one of exactly three places: a node in
   * the same graph, a blode.co-level `@id` the hub defines, or a zone-level
   * `@id` the zone's own home page defines. The third is not a loophole — it
   * is the whole mechanism. `about: {"@id": ".../convene/#software"}` on an
   * article page is how that page says it is about the same product the home
   * page describes, and a crawler merges the two by that id. Anything outside
   * those three is a dangling pointer, which is worse than no pointer.
   */
  it("resolves every reference in-graph, in the zone, or at the root", () => {
    const resolvable = new Set([...ids(graph), ...ids(homePageSchema(FAQ))]);
    for (const ref of references(graph["@graph"])) {
      expect(
        resolvable.has(ref) || ref.startsWith(ROOT_ENTITY_PREFIX),
        `${ref} resolves to nothing`
      ).toBe(true);
    }
  });

  it("ties every node to the WebSite rather than leaving it floating", () => {
    for (const node of graph["@graph"]) {
      const typed = node as { "@type": string; isPartOf?: { "@id": string } };
      if (typed["@type"] === "WebPage" || typed["@type"] === "FAQPage") {
        expect(typed.isPartOf, `${typed["@type"]} has no isPartOf`).toEqual({
          "@id": "https://blode.co/#website",
        });
      }
    }
  });
});

describe("the BreadcrumbList", () => {
  const breadcrumb = homePageSchema(FAQ)["@graph"].find(
    (node) => node["@type"] === "BreadcrumbList"
  ) as { itemListElement: { item: string; name: string; position: number }[] };

  /**
   * The visible trail and the BreadcrumbList must read the same words in the
   * same order — Google treats a mismatch as a markup error, and the two live in
   * different files, so nothing but this notices when one is edited.
   *
   * `ZoneBreadcrumb` is shared byte-for-byte across the fleet and renders these
   * three names; the assertion is on the schema half, which is the half that
   * changes when a product is renamed.
   */
  it("names Matthew Blode, Projects, then the product, in order", () => {
    expect(breadcrumb.itemListElement.map((item) => item.name)).toEqual([
      "Matthew Blode",
      "Projects",
      "Convene",
    ]);
  });

  it("numbers its positions from one, without gaps", () => {
    expect(breadcrumb.itemListElement.map((item) => item.position)).toEqual([
      1, 2, 3,
    ]);
  });

  it("resolves its trail to real blode.co URLs", () => {
    for (const item of breadcrumb.itemListElement) {
      expect(item.item.startsWith("https://blode.co")).toBe(true);
    }
  });

  /** The long-form pages declare no trail on purpose: they render none, and
   * `zone-breadcrumb.tsx` is explicit that the visible trail and the markup have
   * to match. A BreadcrumbList nothing draws is the same defect from the other
   * side. */
  it("is not declared on a page that renders no trail", () => {
    for (const graph of ARTICLE_PAGES) {
      expect(
        graph["@graph"].some((node) => node["@type"] === "BreadcrumbList")
      ).toBe(false);
    }
  });
});

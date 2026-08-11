import { AnswerBlock } from "@/components/marketing/answer-block";
import { ClosingCta } from "@/components/marketing/closing-cta";
import { DataFlow } from "@/components/marketing/data-flow";
import { FaqSection } from "@/components/marketing/faq-section";
import { Hero } from "@/components/marketing/hero";
import { HowItWorks } from "@/components/marketing/how-it-works";
import { Iphone } from "@/components/marketing/iphone";
import { Setup } from "@/components/marketing/setup";
import { JsonLd } from "@/components/shared/json-ld";
import { SiteFooter } from "@/components/shared/site-footer";
import { SiteHeader } from "@/components/shared/site-header";
import { ZoneBreadcrumb } from "@/components/shared/zone-breadcrumb";
import { Container } from "@/components/ui/section";
import { FAQ } from "@/lib/faq";
import { getLatestRelease } from "@/lib/release";
import { homePageSchema } from "@/lib/structured-data";

export default async function Page() {
  const release = await getLatestRelease();

  return (
    <>
      <JsonLd data={homePageSchema(FAQ)} />

      <SiteHeader downloadUrl={release.downloadUrl} />

      <main id="main">
        {/* Breadcrumb + hero share one glow plane so the frosted header blurs
            the same atmosphere as the content under it — otherwise the glow
            starts mid-page and reads as a dirty band under the nav. */}
        <div className="relative overflow-hidden">
          <div
            aria-hidden="true"
            className="hero-glow pointer-events-none absolute inset-0"
          />

          {/* Rule 4: the trail is visible, not only in the JSON-LD, and it reads
              exactly as the BreadcrumbList does. It clears the fixed header on
              the hero's behalf, so the hero's own top padding is reduced to
              match. Root page only. */}
          <Container className="relative pt-20 sm:pt-28">
            <ZoneBreadcrumb product="Convene" />
          </Container>

          <Hero release={release} />
        </div>
        {/* The answer sits between the hero and the proof deliberately: it is
            the paragraph an answer engine lifts, so nothing that needs
            interpreting should come before it. */}
        <AnswerBlock />
        <HowItWorks />
        <DataFlow />
        <Setup />
        <Iphone />
        <FaqSection />
        <ClosingCta release={release} />
      </main>

      <SiteFooter />
    </>
  );
}

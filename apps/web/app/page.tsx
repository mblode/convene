import { ClosingCta } from "@/components/marketing/closing-cta";
import { DataFlow } from "@/components/marketing/data-flow";
import { FaqSection } from "@/components/marketing/faq-section";
import { Hero } from "@/components/marketing/hero";
import { HowItWorks } from "@/components/marketing/how-it-works";
import { Iphone } from "@/components/marketing/iphone";
import { Promises } from "@/components/marketing/promises";
import { Setup } from "@/components/marketing/setup";
import { TrustStrip } from "@/components/marketing/trust-strip";
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
        {/* Rule 4: the trail is visible, not only in the JSON-LD, and it reads
            exactly as the BreadcrumbList does. It clears the fixed header on
            the hero's behalf, so the hero's own top padding is reduced to
            match. Root page only. */}
        <Container className="pt-20 sm:pt-28">
          <ZoneBreadcrumb product="Convene" />
        </Container>

        <Hero release={release} />
        <TrustStrip />
        <Promises />
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

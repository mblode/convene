import { ClosingCta } from "@/components/marketing/closing-cta";
import { DataFlow } from "@/components/marketing/data-flow";
import { FaqSection } from "@/components/marketing/faq-section";
import { Features } from "@/components/marketing/features";
import { Hero } from "@/components/marketing/hero";
import { HowItWorks } from "@/components/marketing/how-it-works";
import { Iphone } from "@/components/marketing/iphone";
import { Promises } from "@/components/marketing/promises";
import { Setup } from "@/components/marketing/setup";
import { TrustStrip } from "@/components/marketing/trust-strip";
import { JsonLd } from "@/components/shared/json-ld";
import { SiteFooter } from "@/components/shared/site-footer";
import { SiteHeader } from "@/components/shared/site-header";
import { FAQ } from "@/lib/faq";
import { getLatestRelease } from "@/lib/release";
import {
  faqPageSchema,
  softwareApplicationSchema,
  webSiteSchema,
} from "@/lib/structured-data";

export default async function Page() {
  const release = await getLatestRelease();

  return (
    <>
      <JsonLd data={softwareApplicationSchema()} />
      <JsonLd data={webSiteSchema()} />
      <JsonLd data={faqPageSchema(FAQ)} />

      <SiteHeader downloadUrl={release.downloadUrl} />

      <main id="main">
        <Hero release={release} />
        <TrustStrip />
        <Promises />
        <HowItWorks />
        <Features />
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

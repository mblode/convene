import { Agentation } from "agentation";
import type { Metadata, Viewport } from "next";
import localFont from "next/font/local";

import { MotionProvider } from "@/components/shared/motion-provider";
import {
  ogSiteName,
  siteConfig,
  titleTemplate,
  twitterHandle,
} from "@/lib/config";

import "./globals.css";

const glide = localFont({
  display: "swap",
  src: [
    { path: "./fonts/glide-variable.woff2", style: "normal" },
    { path: "./fonts/glide-variable-italic.woff2", style: "italic" },
  ],
  variable: "--font-glide",
  weight: "100 950",
});

const glideMono = localFont({
  display: "swap",
  src: "./fonts/glide-mono.woff2",
  variable: "--font-glide-mono",
  weight: "400",
});

const siteUrl = "https://blode.co/convene";
const siteTitle =
  "Convene: open-source AI meeting notes for Mac, saved as Markdown";
const siteDescription =
  "Convene records both sides of your call, transcribes it live, and writes the note into a folder you own. No meeting bot joins. There is no Convene server. Open source, macOS and iPhone.";

export const viewport: Viewport = {
  themeColor: "#f7f7f4",
};

export const metadata: Metadata = {
  alternates: {
    canonical: siteUrl,
  },
  appleWebApp: {
    title: "Convene",
  },
  // Rule 10. Both are scalar-valued, so unlike `openGraph` and `twitter` they
  // are not replaced wholesale by a page that sets its own: every route
  // inherits these without restating them.
  authors: [{ name: ogSiteName, url: siteConfig.links.author }],
  creator: ogSiteName,
  description: siteDescription,
  // Includes the basePath: Next does not prefix it onto generated image
  // routes, so a bare origin here resolves og:image to a 404.
  metadataBase: new URL(siteUrl),
  openGraph: {
    description: siteDescription,
    siteName: ogSiteName,
    title: { default: siteTitle, template: titleTemplate },
    type: "website",
    url: siteUrl,
  },
  title: { default: siteTitle, template: titleTemplate },
  // Deliberately only the card type. An inner page declares `openGraph` but not
  // `twitter`, so it inherits this block whole: any `title` or `description`
  // set here became the title and description of every inner card, and
  // /support shared as the home page. Left empty, Next fills both from the
  // page's own metadata. Nothing failed the build, and `<title>` looked right
  // the entire time.
  twitter: {
    card: "summary_large_image",
    creator: twitterHandle,
  },
  verification: {
    google: "mFwyBIbXTaKK4uF_NA0MzVWFyY40hPgBjFObg3rje04",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html className={`${glide.variable} ${glideMono.variable}`} lang="en">
      <head>
        <link href={process.env.NEXT_PUBLIC_POSTHOG_HOST} rel="preconnect" />
      </head>
      <body className="antialiased">
        <a
          className="sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4 focus:z-50 focus:rounded-lg focus:bg-primary focus:px-4 focus:py-2 focus:text-primary-foreground focus:text-sm"
          href="#main"
        >
          Skip to content
        </a>
        <MotionProvider>{children}</MotionProvider>
        {process.env.NODE_ENV === "development" && <Agentation />}
      </body>
    </html>
  );
}

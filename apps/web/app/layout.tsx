import { Agentation } from "agentation";
import { GeistMono } from "geist/font/mono";
import type { Metadata, Viewport } from "next";
import localFont from "next/font/local";

import { MotionProvider } from "@/components/shared/motion-provider";

import "./globals.css";

// Roman only: the site sets no italic text, and the italic face is another
// 124 KB on first paint.
const glide = localFont({
  display: "swap",
  src: [{ path: "../public/glide-variable.woff2", style: "normal" }],
  variable: "--font-glide",
  weight: "400 900",
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
  description: siteDescription,
  // Includes the basePath: Next does not prefix it onto generated image
  // routes, so a bare origin here resolves og:image to a 404.
  metadataBase: new URL(siteUrl),
  openGraph: {
    description: siteDescription,
    siteName: "Convene",
    title: siteTitle,
    type: "website",
    url: siteUrl,
  },
  title: {
    default: siteTitle,
    template: "%s · Convene",
  },
  twitter: {
    card: "summary_large_image",
    description: siteDescription,
    title: siteTitle,
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
    <html className={`${glide.variable} ${GeistMono.variable}`} lang="en">
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

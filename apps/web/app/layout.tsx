import { Agentation } from "agentation";
import type { Metadata } from "next";
import localFont from "next/font/local";

import "./globals.css";

const glide = localFont({
  display: "swap",
  src: [
    { path: "../public/glide-variable.woff2", style: "normal" },
    { path: "../public/glide-variable-italic.woff2", style: "italic" },
  ],
  variable: "--font-glide",
  weight: "400 900",
});
const siteUrl = "https://blode.co/convene";
const siteTitle = "Convene - Open-Source AI Meeting Notes for macOS";
const siteDescription =
  "An open-source Granola clone for macOS. Records your meetings, transcribes them live, and writes the notes into a folder you own.";

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
  title: siteTitle,
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
    <html lang="en" className={glide.variable}>
      <head>
        <link href="https://r.blode.co" rel="preconnect" />
      </head>
      <body className="antialiased">
        {children}
        {process.env.NODE_ENV === "development" && <Agentation />}
      </body>
    </html>
  );
}

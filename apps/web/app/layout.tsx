import type { Metadata } from "next"
import localFont from "next/font/local"
import { Agentation } from "agentation"
import "./globals.css"

const glide = localFont({
  display: "swap",
  src: [
    { path: "../public/glide-variable.woff2", style: "normal" },
    { path: "../public/glide-variable-italic.woff2", style: "italic" },
  ],
  variable: "--font-glide",
  weight: "400 900",
})

export const metadata: Metadata = {
  appleWebApp: {
    title: "Convene",
  },
  description:
    "Open-source meeting transcription for macOS. Records both sides of the call and transcribes live — bring your own API keys, no subscription.",
  metadataBase: new URL("https://convene.blode.co"),
  openGraph: {
    description:
      "Open-source meeting transcription for macOS. Records both sides of the call and transcribes live — bring your own API keys, no subscription.",
    siteName: "Convene",
    title: "Convene",
  },
  title: "Convene",
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en" className={glide.variable}>
      <body className="antialiased">
        {children}
        {process.env.NODE_ENV === "development" && <Agentation />}
      </body>
    </html>
  )
}

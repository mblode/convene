import type { NextConfig } from "next";

const posthogOrigin = process.env.NEXT_PUBLIC_POSTHOG_HOST ?? "";

const contentSecurityPolicy = [
  "default-src 'self'",
  // 'unsafe-eval' only in dev: Turbopack's HMR runtime needs it. The site
  // ships no eval in production.
  `script-src 'self' 'unsafe-inline' ${posthogOrigin}${
    process.env.NODE_ENV === "development" ? " 'unsafe-eval'" : ""
  }`,
  `connect-src 'self' ${posthogOrigin}`,
  "img-src 'self' data:",
  "style-src 'self' 'unsafe-inline'",
  "font-src 'self'",
  "object-src 'none'",
  "base-uri 'self'",
  "form-action 'self'",
  "frame-ancestors 'self'",
  "upgrade-insecure-requests",
].join("; ");

const securityHeaders = [
  { key: "Content-Security-Policy", value: contentSecurityPolicy },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "X-Frame-Options", value: "SAMEORIGIN" },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "X-DNS-Prefetch-Control", value: "on" },
  {
    key: "Strict-Transport-Security",
    value: "max-age=63072000; includeSubDomains; preload",
  },
  {
    key: "Permissions-Policy",
    value: "camera=(), microphone=(), geolocation=(), payment=()",
  },
  { key: "Cross-Origin-Opener-Policy", value: "same-origin" },
  { key: "Cross-Origin-Resource-Policy", value: "same-origin" },
];

/** Social cards are fetched by other origins, so they need a looser CORP than
 * the rest of the site. */
const crossOrigin = [
  ...securityHeaders.filter((h) => h.key !== "Cross-Origin-Resource-Policy"),
  { key: "Cross-Origin-Resource-Policy", value: "cross-origin" },
];

const nextConfig: NextConfig = {
  assetPrefix: "/convene",
  basePath: "/convene",
  experimental: { turbopackRustReactCompiler: true },
  headers() {
    return Promise.resolve([
      { headers: crossOrigin, source: "/opengraph-image" },
      { headers: crossOrigin, source: "/twitter-image" },
      { headers: crossOrigin, source: "/web-app-manifest-:size.png" },
      // ":path*", not "(.*)": under a basePath the latter compiles to
      // "/convene/(.*)", which needs at least one segment and so skips the
      // landing page itself. ":path*" matches zero segments too.
      { headers: securityHeaders, source: "/:path*" },
    ]);
  },
  reactCompiler: true,
  redirects() {
    return Promise.resolve([
      // "granola vs convene" is the other half of the same query; send it to
      // the page that answers it rather than maintaining two.
      {
        destination: "/granola-alternative",
        permanent: true,
        source: "/granola-vs-convene",
      },
      {
        destination: "/granola-alternative",
        permanent: true,
        source: "/convene-vs-granola",
      },
      {
        basePath: false,
        destination: "https://blode.co/convene",
        has: [{ type: "host" as const, value: "convene.blode.co" }],
        permanent: true,
        source: "/",
      },
      {
        basePath: false,
        destination: "https://blode.co/convene/:path*",
        has: [{ type: "host" as const, value: "convene.blode.co" }],
        permanent: true,
        source: "/:path*",
      },
    ]);
  },
};

export default nextConfig;

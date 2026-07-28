import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  assetPrefix: "/convene",
  basePath: "/convene",
  /**
   * Keep the non-canonical hostnames out of the index.
   *
   * This app canonicalises to blode.co/convene, but it also answers on the
   * origin blode.co proxies to and on its *.vercel.app aliases. Those sit
   * inside the sc-domain:blode.co Search Console property, so left alone they
   * are a crawlable duplicate of the whole site.
   *
   * The discriminator is x-forwarded-host, NOT host: the multi-zone rewrite
   * proxies to the origin, so `host` is the origin for real blode.co traffic
   * too. x-forwarded-host keeps the hostname the client actually asked for,
   * which is blode.co when proxied. Matching on `host` would noindex the
   * live site.
   */
  headers() {
    return Promise.resolve([
      {
        has: [
          {
            key: "x-forwarded-host",
            type: "header" as const,
            value: String.raw`.*\.zone\.blode\.co|.*\.vercel\.app`,
          },
        ],
        headers: [{ key: "X-Robots-Tag", value: "noindex" }],
        source: "/:path*",
      },
    ]);
  },
  reactCompiler: true,
  redirects() {
    return Promise.resolve([
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
  typescript: { ignoreBuildErrors: true },
};

export default nextConfig;

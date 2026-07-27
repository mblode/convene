import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  assetPrefix: "/convene",
  basePath: "/convene",
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

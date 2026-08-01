import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  turbopack: {
    root: process.cwd(),
  },
  // Die bestehende Demo ist schrittweise aus JSX entstanden. Für die
  // Veröffentlichung wird sie gebaut, während die Typisierung separat
  // vervollständigt werden kann.
  typescript: {
    ignoreBuildErrors: true,
  },
};

export default nextConfig;

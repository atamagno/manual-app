import { build } from "esbuild";
import process from "node:process";
import type { BuildOptions } from "esbuild";

const isProd = process.env.NODE_ENV === "production";

const buildOptions: BuildOptions = {
  entryPoints: ["src/index.ts"],
  bundle: true,
  platform: "node",
  target: "node20",
  outfile: "dist/index.js",
  minify: isProd,
  sourcemap: !isProd,
  external: [],
};

build(buildOptions).catch(() => process.exit(1));

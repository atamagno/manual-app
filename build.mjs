import { build } from "esbuild";
import process from "node:process";

const isProd = process.env.NODE_ENV === "production";

build({
  entryPoints: ["src/index.ts"],
  bundle: true,
  platform: "node",
  target: "node20",
  format: "esm",
  outfile: "dist/index.js",
  minify: isProd,
  sourcemap: !isProd,
}).catch(() => process.exit(1));

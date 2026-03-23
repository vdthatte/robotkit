import { build } from "esbuild";
import { mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";

const entry = resolve("RuntimeSources/robotkit-runtime.js");
const outfile = resolve("RobotKit/Resources/JavaScript/robotkit-runtime.bundle.js");

await mkdir(dirname(outfile), { recursive: true });

await build({
  entryPoints: [entry],
  outfile,
  bundle: true,
  format: "iife",
  platform: "browser",
  target: "es2020",
  sourcemap: false,
  logLevel: "info",
  banner: {
    js: "var global = globalThis;"
  }
});

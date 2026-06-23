// Bundles each action's `main.ts` into a self-contained `dist/index.js` that
// GitHub Actions can run directly (Actions does not install dependencies at
// runtime). Discovers every `actions/<name>/main.ts` entry point.

import { build } from "esbuild";
import { existsSync, readdirSync } from "node:fs";

const actions = readdirSync("actions", { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name)
  .filter((name) => existsSync(`actions/${name}/main.ts`));

await Promise.all(
  actions.map((name) =>
    build({
      entryPoints: [`actions/${name}/main.ts`],
      outfile: `actions/${name}/dist/index.js`,
      bundle: true,
      platform: "node",
      target: "node20",
      format: "cjs",
    }),
  ),
);

console.log(`Built ${actions.length} action(s): ${actions.join(", ")}`);

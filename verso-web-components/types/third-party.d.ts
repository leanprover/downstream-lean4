// The third-party libraries that the pages load as global scripts or from a CDN. The
// packages in `devDependencies` provide their types.

/// <reference types="glightbox" />

declare const tippy: typeof import("tippy.js").default;

interface Window {
    Motion?: typeof import("motion");
}

declare module "https://cdn.jsdelivr.net/npm/motion@latest/+esm" {
    export * from "motion";
}

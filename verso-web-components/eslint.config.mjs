import globals from "globals";
import shared from "./eslint.shared.mjs";

// The `ignores` and `files` entries describe this repository, and the shared presets and rules
// come last. The vendored GLightbox and Motion libraries are ignored.
export default [
    {
        ignores: [
            "**/*.min.js",
            "node_modules/",
            ".lake/",
            "**/.lake/",
            "_out/",
            "deps/",
            "static/js/motion.js",
        ],
    },
    {
        files: ["**/*.js"],
        languageOptions: {
            ecmaVersion: 2024,
            sourceType: "script",
            // Pages that use these scripts load Tippy.js and GLightbox first.
            globals: { ...globals.browser, tippy: "readonly", GLightbox: "readonly" },
        },
    },
    ...shared,
];

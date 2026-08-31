/* Nur fuer scripts/pruefe-hooks.mjs. Die Regel steht hier getrennt, weil sie
 * roh viel zu viel meldet - siehe Kommentar dort. */
import parser from "@typescript-eslint/parser";
import globals from "globals";

export default [{
  files: ["app/**/*.tsx", "app/**/*.ts", "lib/**/*.ts"],
  languageOptions: {
    parser,
    parserOptions: { ecmaFeatures: { jsx: true }, ecmaVersion: "latest", sourceType: "module" },
    globals: { ...globals.browser, ...globals.node, React: "readonly" },
  },
  rules: {
    "no-use-before-define": ["error", { functions: false, classes: false, variables: true }],
  },
}];

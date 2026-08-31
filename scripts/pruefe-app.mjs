/* Prueft app/page.tsx auf zwei Fehlerklassen, die weder tsc noch der Build
 * melden:
 *
 *   no-undef                  Zuweisung an eine nicht deklarierte Variable.
 *                             Genau das ist am 03.09. passiert: Beim Ersetzen
 *                             eines Kommentars fiel ein "const" mit weg. Der
 *                             Build lief durch, tsc schwieg - im Modulkontext
 *                             waere es beim ersten Aufruf ein ReferenceError
 *                             gewesen.
 *   react-hooks/rules-of-hooks  Hooks hinter einem fruehen return.
 *
 * Aufruf: npx eslint --config scripts/pruefe-app.mjs app/page.tsx
 */
import hooks from "eslint-plugin-react-hooks";
import parser from "@typescript-eslint/parser";
import globals from "globals";

export default [{
  files: ["app/**/*.tsx", "app/**/*.ts", "lib/**/*.ts"],
  languageOptions: {
    parser,
    parserOptions: { ecmaFeatures: { jsx: true }, ecmaVersion: "latest", sourceType: "module" },
    globals: { ...globals.browser, ...globals.node, React: "readonly" },
  },
  plugins: { "react-hooks": hooks },
  rules: {
    "no-undef": "error",
    "react-hooks/rules-of-hooks": "error",
  },
}];

import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",
    // Erzeugnis von "vite build" fuer den Test der Server-Huelle.
    "dist/**",
  ]),
  {
    /* Regeln des React Compilers: Hinweis statt Fehler.
     *
     * eslint-plugin-react-hooks 7 bringt die Regeln mit, die der React Compiler
     * braucht. Dieses Projekt benutzt den Compiler nicht - die Regeln kamen mit
     * einem Versions-Upgrade ins Haus, nicht durch eine Entscheidung. Sie
     * treffen dadurch gewachsene, funktionierende Muster:
     *
     *   set-state-in-effect  - trifft jedes Laden der Form
     *                          useEffect(() => { laden(); }, [laden])
     *                          und jede Schutzklausel, die im Effekt einen
     *                          Vorgabewert setzt. Das umzubauen hiesse, das
     *                          Laden der gesamten App neu zu bauen.
     *   purity               - meldet Date.now() auch dort, wo es in einem
     *                          Klick- oder Absende-Handler steht und den
     *                          Rendervorgang gar nicht beruehrt.
     *   immutability         - meldet Funktionen, die weiter unten deklariert
     *                          sind, aber erst nach dem Rendern aufgerufen
     *                          werden.
     *   preserve-manual-memoization - meldet useCallback, dessen Memoisierung
     *                          der Compiler nicht uebernehmen koennte.
     *
     * Als Hinweis bleiben sie sichtbar, ohne den Lauf rot zu faerben. So faellt
     * ein NEUER Fehler wieder auf - vorher gingen echte Funde in 50 alten
     * Meldungen unter, und genau das ist einmal passiert.
     *
     * Was BEWUSST Fehler bleibt: rules-of-hooks und exhaustive-deps, also die
     * beiden klassischen Regeln, sowie alles ausserhalb von react-hooks.
     * Ebenfalls behoben statt abgestuft wurden refs (Zuweisung waehrend des
     * Renderns) und static-components (Komponente in einer Komponente) - dort
     * war die Regel im Recht.
     *
     * Wird der React Compiler eingefuehrt, gehoeren diese vier zurueck auf
     * "error" und die Fundstellen einzeln durchgearbeitet.
     */
    rules: {
      "react-hooks/set-state-in-effect": "warn",
      "react-hooks/purity": "warn",
      "react-hooks/immutability": "warn",
      "react-hooks/preserve-manual-memoization": "warn",
    },
  },
]);

export default eslintConfig;

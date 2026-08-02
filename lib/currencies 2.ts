// Währungsauswahl bei der Vereinsregistrierung. EUR ist Standard/erster Eintrag.
export interface Currency {
  code: string; // ISO 4217
  label: string;
  symbol: string;
}

export const CURRENCIES: Currency[] = [
  { code: "EUR", label: "Euro", symbol: "€" },
  { code: "CHF", label: "Schweizer Franken", symbol: "CHF" },
  { code: "GBP", label: "Britisches Pfund", symbol: "£" },
  { code: "USD", label: "US-Dollar", symbol: "$" },
  { code: "SEK", label: "Schwedische Krone", symbol: "kr" },
  { code: "NOK", label: "Norwegische Krone", symbol: "kr" },
  { code: "DKK", label: "Dänische Krone", symbol: "kr" },
  { code: "PLN", label: "Polnischer Złoty", symbol: "zł" },
  { code: "CZK", label: "Tschechische Krone", symbol: "Kč" },
  { code: "HUF", label: "Ungarischer Forint", symbol: "Ft" },
  { code: "RON", label: "Rumänischer Leu", symbol: "lei" },
];

export const DEFAULT_CURRENCY = "EUR";

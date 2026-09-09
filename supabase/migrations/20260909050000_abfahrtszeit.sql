/* Wann faehrt der Fahrer los?

 * Eine Fahrgemeinschaft trug bisher nur den ORT der Abfahrt (departure) und
 * die Zahl der freien Plaetze. Wann es losgeht, stand nirgends - wer
 * mitfahren wollte, musste im Chat nachfragen. Genau die Rueckfragen soll die
 * App abnehmen.
 *
 * Eigene Spalte statt eines Zusatzes im Notizfeld: Eine Uhrzeit im Freitext
 * laesst sich weder sortieren noch in der Sprache des Lesers anzeigen, und
 * spaetestens beim Kalender oder einer Erinnerung braucht es einen echten
 * Zeitpunkt.
 *
 * NULL bleibt erlaubt. Die bestehenden Fahrgemeinschaften haben keine Zeit,
 * und ihnen eine zu erfinden waere schlimmer als sie offen zu lassen - die
 * Anzeige laesst die Zeile dann einfach weg. Neue Angebote verlangen die
 * Angabe in der Oberflaeche.
 */
alter table public.carpools add column if not exists departure_at timestamptz;

comment on column public.carpools.departure_at is
  'Wann der Fahrer losfaehrt. NULL bei Angeboten aus der Zeit vor dieser Spalte.';

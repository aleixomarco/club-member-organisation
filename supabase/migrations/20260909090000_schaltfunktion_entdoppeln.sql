/* Eine Fassung von mannschaft_funktionen_setzen, nicht zwei.

 * WAS ICH FALSCH GEMACHT HABE
 * 20260909070000 hat der Funktion den Parameter p_zusagen_spiele hinzugefuegt -
 * mit "create or replace". Das ersetzt aber nur bei GLEICHER Signatur. Ein
 * zusaetzlicher Parameter ergibt eine andere Signatur, also stand die Funktion
 * danach zweimal da:
 *     (uuid, boolean, boolean)
 *     (uuid, boolean, boolean, boolean)
 *
 * WAS DAS ANGERICHTET HAT
 * PostgREST loest ueber die NAMEN der uebergebenen Argumente auf. Die
 * ausgelieferte App schickt drei - target_team, p_zusagen, p_strafen -, und
 * die passen auf BEIDE Fassungen, weil der vierte Parameter einen Vorgabewert
 * hat. Ergebnis:
 *     function public.mannschaft_funktionen_setzen(...) is not unique
 * Der Schalter "Zusagen erlauben" liess sich damit gar nicht mehr speichern:
 * Er kippte, der Aufruf scheiterte, die App nahm ihn zurueck. Gemeldet wurde
 * es aus dem Betrieb, nicht von einem Test - genau deshalb steht dieser
 * Absatz hier.
 *
 * DIE BEHEBUNG
 * Die alte Fassung faellt weg. Danach gibt es genau eine, und beide
 * Aufrufformen landen dort: Wer drei Argumente schickt, laesst
 * p_zusagen_spiele auf seinem Vorgabewert NULL - und coalesce im Rumpf laesst
 * die Spalte dann unangetastet. Die ausgelieferte App funktioniert also
 * weiter, ohne dass sie etwas davon wissen muss.
 *
 * DIE LEHRE, weil sie im Projekt nicht neu ist (siehe
 * 20260907170000_profilfunktion_entdoppeln): Wer einer Funktion einen
 * Parameter hinzufuegt, muss die alte Signatur ausdruecklich loeschen.
 */
drop function if exists public.mannschaft_funktionen_setzen(uuid, boolean, boolean);

-- Indizes fuer die Abfragen, die mit der Nutzerzahl mitwachsen.
--
-- DIE FRAGE WAR: Wird die App langsamer, wenn statt 10 Leuten 10.000 sie
-- benutzen? Die ehrliche Antwort ist: Nicht wegen der 10.000 Leute - aber
-- wegen der Zeilen, die sie erzeugen.
--
-- WAS BEIM NACHSEHEN HERAUSKAM
-- Fuenf Abfragen holen ihre Daten OHNE Vereinsfilter und verlassen sich
-- allein auf die Zeilenregeln: predictions, poll_options, poll_votes,
-- duty_assignments, protocol_tasks. Die Regel entscheidet zuverlaessig, wer
-- was sehen darf - aber sie muss dafuer JEDE Zeile ansehen, auch die von
-- fremden Vereinen. Der Aufwand waechst also nicht mit der Groesse des
-- eigenen Vereins, sondern mit der Summe aller.
--
-- Das hier ist die Haelfte der Loesung: Wo eine Regel oder eine Abfrage auf
-- eine Spalte zeigt, die keinen Index hat, wird gelesen statt gesucht.
--
-- club_tasks hatte ueberhaupt nur den Schluessel auf id - die App filtert
-- aber auf club_id. Bei vier Aufgaben faellt das nicht auf. Bei 500 Vereinen
-- mit je 50 Aufgaben liest die Datenbank 25.000 Zeilen, um vier zu finden,
-- und zwar bei jedem Start der App.
--
-- Die andere Haelfte - die Abfragen selbst einzugrenzen - steht noch aus und
-- ist die groessere Aenderung.

/* Die App filtert darauf, es gab aber keinen Index. */
create index if not exists club_tasks_club_id_idx on public.club_tasks (club_id);

/* Die Zeilenregel verbindet ueber protocol_id; ohne Index wird die
   Aufgabenliste jedes Protokolls einzeln durchgelesen. */
create index if not exists protocol_tasks_protocol_id_idx on public.protocol_tasks (protocol_id);

/* "Meine Tipps", "meine Stimme", "meine Dienste", "meine Zusage" - vier
   Abfragen, die alle nach der eigenen Person suchen und dafuer bisher die
   ganze Tabelle lesen mussten. Der jeweils vorhandene Index beginnt mit der
   anderen Spalte und hilft dabei nicht. */
create index if not exists predictions_profile_id_idx on public.predictions (profile_id);
create index if not exists poll_votes_profile_id_idx on public.poll_votes (profile_id);
create index if not exists duty_assignments_membership_id_idx on public.duty_assignments (membership_id);
create index if not exists event_attendance_membership_id_idx on public.event_attendance (membership_id);

/* Nachrichten einer Person - fuer das Melden und Sperren von Autoren. */
create index if not exists messages_author_id_idx on public.messages (author_id);

/* Die Benachrichtigungen eines Vereins, etwa beim Aufraeumen. Der
   vorhandene Index beginnt mit profile_id und hilft dafuer nicht. */
create index if not exists user_notifications_club_id_idx on public.user_notifications (club_id, created_at desc);

/* Beitraege eines Vereins - die Beitragsverwaltung liest sie vollstaendig. */
create index if not exists fee_records_club_id_idx on public.fee_records (club_id, year desc);

analyze public.club_tasks;
analyze public.protocol_tasks;
analyze public.predictions;
analyze public.poll_votes;
analyze public.duty_assignments;
analyze public.event_attendance;
analyze public.messages;
analyze public.user_notifications;
analyze public.fee_records;

select count(*) as neue_indizes from pg_indexes
where schemaname = 'public' and indexname in (
  'club_tasks_club_id_idx','protocol_tasks_protocol_id_idx','predictions_profile_id_idx',
  'poll_votes_profile_id_idx','duty_assignments_membership_id_idx','event_attendance_membership_id_idx',
  'messages_author_id_idx','user_notifications_club_id_idx','fee_records_club_id_idx');

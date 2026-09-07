-- Alle Benachrichtigungen kommen jetzt in der Sprache des Empfaengers an.
--
-- WAS BISHER PASSIERTE
-- Wer die App auf Tuerkisch stellt, bekam eine tuerkische Oberflaeche - und
-- deutsche Mitteilungen auf den Sperrbildschirm. "Das Training wurde
-- abgesagt." stand als fertiger deutscher Satz in den Ausloesern.
--
-- Uebersetzt war genau EINE Meldungsart: die Umfrage (20260907010000). Alle
-- anderen 83 Textbausteine waren deutsch.
--
-- WARUM DAS NICHT IN DER APP ZU LOESEN IST
-- lib/sprachen.ts laeuft im Browser. Eine Push-Meldung wird verschickt,
-- waehrend die App geschlossen ist - da laeuft nichts, was uebersetzen
-- koennte. Der Text muss fertig sein, wenn er die Datenbank verlaesst.
--
-- Der Ausloeser kennt den Empfaenger, der Empfaenger hat eine Sprache
-- (profiles.language). Also wird jede Zeile gleich richtig geschrieben.
-- Angenehmer Nebeneffekt: Glocke und Push zeigen dasselbe, weil beide
-- dieselbe Zeile lesen.
--
-- WAS NICHT UEBERSETZT WIRD
--   - Betreibernachrichten: freier Text, den wir selbst eintippen
--   - Chat: der Nachrichtentext des Absenders bleibt, wie er ihn schrieb
--   - Namen, Vereins- und Mannschaftsnamen, Aufgabentitel
--   - sechs tote notify_*-Funktionen (kein Ausloeser, kein Aufrufer):
--     notify_event_created, notify_event_updated, notify_join_request_decided,
--     notify_new_device, notify_new_join_request, notify_news_posted
--
-- ZWEI DINGE, DIE BEIM UEBERSETZEN AUFFIELEN
--
-- 1. "Das {art} wurde angelegt." laesst sich nicht zusammensetzen. Im
--    Deutschen geht "Das Training"/"Das Spiel", im Spanischen braucht es
--    "El entrenamiento"/"El partido" - Artikel und Geschlecht haengen am
--    Wort. Deshalb stehen alle neun Termin-Meldungen als GANZE Saetze im
--    Katalog, nicht als Bausteine.
--
-- 2. Ersatzwoerter, die IN einen Satz gesetzt werden, sind eine Falle. Fehlt
--    der Name einer Strafe, stand bisher "Eine Strafe wurde dir zugewiesen."
--    Auf Franzoesisch wurde daraus "Tu as reçu une sanction : Une sanction."
--    Fuer diesen Fall gibt es jetzt eigene Saetze statt eines eingesetzten
--    Wortes.

-- ---------------------------------------------------- Textbausteine ersetzen
--
-- meldungstext bekommt einen dritten Parameter: die Werte fuer die
-- Platzhalter. Ein Text wie "{wer} hat dir eine Aufgabe zugewiesen: {titel}"
-- wird damit erst in der Zielsprache gesucht und dann gefuellt - nicht
-- umgekehrt, denn die Wortstellung ist je Sprache verschieden.
create or replace function public.meldungstext(p_schluessel text, p_sprache text, p_werte jsonb)
returns text language plpgsql stable security definer set search_path = 'public' as $$
declare v_text text; v_k text;
begin
  select text into v_text from public.meldungstexte
   where schluessel = p_schluessel and sprache = coalesce(p_sprache, 'de');
  if v_text is null then
    select text into v_text from public.meldungstexte
     where schluessel = p_schluessel and sprache = 'de';
  end if;
  /* Fehlt auch der deutsche Baustein, kommt der Schluessel zurueck. Haesslich,
     aber sichtbar - eine leere Mitteilung saehe aus wie ein Fehler im
     Versand und wuerde niemandem sagen, was fehlt. */
  if v_text is null then return p_schluessel; end if;

  if p_werte is not null and jsonb_typeof(p_werte) = 'object' then
    for v_k in select jsonb_object_keys(p_werte) loop
      v_text := replace(v_text, '{' || v_k || '}', coalesce(p_werte ->> v_k, ''));
    end loop;
  end if;
  return v_text;
end;
$$;

/* Die zweistellige Form bleibt - sie wird von umfrage_melden benutzt und ist
   der haeufige Fall ohne Platzhalter. */
create or replace function public.meldungstext(p_schluessel text, p_sprache text)
returns text language sql stable security definer set search_path = 'public' as $$
  select public.meldungstext(p_schluessel, p_sprache, '{}'::jsonb);
$$;

grant execute on function public.meldungstext(text, text)        to authenticated, service_role;
grant execute on function public.meldungstext(text, text, jsonb) to authenticated, service_role;

-- ------------------------------------------------ Sprache des Empfaengers
create or replace function public.sprache_der_mitgliedschaft(p_membership uuid)
returns text language sql stable security definer set search_path = 'public' as $$
  select coalesce(p.language, 'de')
    from public.club_memberships m
    left join public.profiles p on p.id = m.profile_id
   where m.id = p_membership;
$$;

comment on function public.sprache_der_mitgliedschaft(uuid) is
  'Sprache, in der diese Mitgliedschaft Benachrichtigungen bekommen will. Ohne Profil oder ohne Angabe: Deutsch.';

/* notify mit Uebersetzung.
   Die freie Form von notify bleibt bestehen - Betreibernachrichten sind
   getippter Text und haben keinen Schluessel. */
create or replace function public.notify_uebersetzt(
  target_membership uuid,
  p_notif_type text,
  p_titel_schluessel text,
  p_text_schluessel text default null,
  p_werte jsonb default '{}'::jsonb,
  p_data jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path = 'public' as $$
declare v_sprache text;
begin
  v_sprache := public.sprache_der_mitgliedschaft(target_membership);
  perform public.notify(
    target_membership,
    p_notif_type,
    public.meldungstext(p_titel_schluessel, v_sprache, p_werte),
    case when p_text_schluessel is null then null
         else public.meldungstext(p_text_schluessel, v_sprache, p_werte) end,
    p_data);
end;
$$;

grant execute on function public.notify_uebersetzt(uuid, text, text, text, jsonb, jsonb) to service_role;
insert into public.meldungstexte (schluessel, sprache, text) values
  ('aufgabe.neu.titel','de','Eine neue Aufgabe wurde erstellt.'),
  ('aufgabe.neu.titel','en','New task created'),
  ('aufgabe.neu.titel','es','Se ha creado una nueva tarea.'),
  ('aufgabe.neu.titel','pt','Nova tarefa criada'),
  ('aufgabe.neu.titel','it','Nuova attività creata'),
  ('aufgabe.neu.titel','tr','Yeni bir görev oluşturuldu.'),
  ('aufgabe.neu.titel','fr','Nouvelle tâche créée'),
  ('aufgabe.neu.text','de','{titel} · bis {datum}'),
  ('aufgabe.neu.text','en','{titel} · due {datum}'),
  ('aufgabe.neu.text','es','{titel} · hasta el {datum}'),
  ('aufgabe.neu.text','pt','{titel} · até {datum}'),
  ('aufgabe.neu.text','it','{titel} · entro il {datum}'),
  ('aufgabe.neu.text','tr','{titel} · son tarih {datum}'),
  ('aufgabe.neu.text','fr','{titel} · avant le {datum}'),
  ('aufgabe.neu.textOhneDatum','de','{titel}'),
  ('aufgabe.neu.textOhneDatum','en','{titel}'),
  ('aufgabe.neu.textOhneDatum','es','{titel}'),
  ('aufgabe.neu.textOhneDatum','pt','{titel}'),
  ('aufgabe.neu.textOhneDatum','it','{titel}'),
  ('aufgabe.neu.textOhneDatum','tr','{titel}'),
  ('aufgabe.neu.textOhneDatum','fr','{titel}'),
  ('aufgabe.zugewiesen.titel','de','Neue Aufgabe'),
  ('aufgabe.zugewiesen.titel','en','New task'),
  ('aufgabe.zugewiesen.titel','es','Nueva tarea'),
  ('aufgabe.zugewiesen.titel','pt','Nova tarefa'),
  ('aufgabe.zugewiesen.titel','it','Nuova attività'),
  ('aufgabe.zugewiesen.titel','tr','Yeni görev'),
  ('aufgabe.zugewiesen.titel','fr','Nouvelle tâche'),
  ('aufgabe.zugewiesen.text','de','{wer} hat dir eine Aufgabe zugewiesen.'),
  ('aufgabe.zugewiesen.text','en','{wer} assigned you a task.'),
  ('aufgabe.zugewiesen.text','es','{wer} te ha asignado una tarea.'),
  ('aufgabe.zugewiesen.text','pt','{wer} atribuiu-te uma tarefa.'),
  ('aufgabe.zugewiesen.text','it','{wer} ti ha assegnato un''attività.'),
  ('aufgabe.zugewiesen.text','tr','{wer} sana bir görev atadı.'),
  ('aufgabe.zugewiesen.text','fr','{wer} t''a attribué une tâche.'),
  ('aufgabe.zugewiesen.textMitTitel','de','{wer} hat dir eine Aufgabe zugewiesen: {titel}'),
  ('aufgabe.zugewiesen.textMitTitel','en','{wer} assigned you a task: {titel}'),
  ('aufgabe.zugewiesen.textMitTitel','es','{wer} te ha asignado una tarea: {titel}'),
  ('aufgabe.zugewiesen.textMitTitel','pt','{wer} atribuiu-te uma tarefa: {titel}'),
  ('aufgabe.zugewiesen.textMitTitel','it','{wer} ti ha assegnato un''attività: {titel}'),
  ('aufgabe.zugewiesen.textMitTitel','tr','{wer} sana bir görev atadı: {titel}'),
  ('aufgabe.zugewiesen.textMitTitel','fr','{wer} t''a attribué une tâche : {titel}'),
  ('allg.vereinsleitung','de','Die Vereinsleitung'),
  ('allg.vereinsleitung','en','The club board'),
  ('allg.vereinsleitung','es','La directiva del club'),
  ('allg.vereinsleitung','pt','A direção do clube'),
  ('allg.vereinsleitung','it','La dirigenza della società'),
  ('allg.vereinsleitung','tr','Kulüp yönetimi'),
  ('allg.vereinsleitung','fr','La direction du club'),
  ('erinnerung.titel','de','Erinnerung'),
  ('erinnerung.titel','en','Reminder'),
  ('erinnerung.titel','es','Recordatorio'),
  ('erinnerung.titel','pt','Lembrete'),
  ('erinnerung.titel','it','Promemoria'),
  ('erinnerung.titel','tr','Hatırlatma'),
  ('erinnerung.titel','fr','Rappel'),
  ('erinnerung.morgen','de','Erinnerung für morgen: {titel}'),
  ('erinnerung.morgen','en','Due tomorrow: {titel}'),
  ('erinnerung.morgen','es','Recordatorio para mañana: {titel}'),
  ('erinnerung.morgen','pt','Lembrete para amanhã: {titel}'),
  ('erinnerung.morgen','it','Promemoria per domani: {titel}'),
  ('erinnerung.morgen','tr','Yarın için hatırlatma: {titel}'),
  ('erinnerung.morgen','fr','Rappel pour demain : {titel}'),
  ('beitritt.angenommen.titel','de','Deine Beitrittsanfrage wurde angenommen.'),
  ('beitritt.angenommen.titel','en','Your join request was accepted.'),
  ('beitritt.angenommen.titel','es','Se ha aceptado tu solicitud de ingreso.'),
  ('beitritt.angenommen.titel','pt','Pedido de adesão aceite'),
  ('beitritt.angenommen.titel','it','La tua iscrizione è stata accettata'),
  ('beitritt.angenommen.titel','tr','Üyelik başvurun kabul edildi.'),
  ('beitritt.angenommen.titel','fr','Ta demande d''adhésion a été acceptée.'),
  ('beitritt.angenommen.text','de','Willkommen bei {verein}.'),
  ('beitritt.angenommen.text','en','Welcome to {verein}.'),
  ('beitritt.angenommen.text','es','Te damos la bienvenida a {verein}.'),
  ('beitritt.angenommen.text','pt','{verein} dá-te as boas-vindas!'),
  ('beitritt.angenommen.text','it','{verein} ti dà il benvenuto!'),
  ('beitritt.angenommen.text','tr','Hoş geldin! Artık {verein} üyesisin.'),
  ('beitritt.angenommen.text','fr','Bienvenue à {verein}.'),
  ('beitritt.abgelehnt.titel','de','Deine Beitrittsanfrage wurde abgelehnt.'),
  ('beitritt.abgelehnt.titel','en','Your join request was declined.'),
  ('beitritt.abgelehnt.titel','es','Se ha rechazado tu solicitud de ingreso.'),
  ('beitritt.abgelehnt.titel','pt','Pedido de adesão recusado'),
  ('beitritt.abgelehnt.titel','it','Richiesta di iscrizione rifiutata'),
  ('beitritt.abgelehnt.titel','tr','Üyelik başvurun reddedildi.'),
  ('beitritt.abgelehnt.titel','fr','Ta demande d''adhésion a été refusée.'),
  ('beitritt.abgelehnt.text','de','Wende dich an die Leitung von {verein}, wenn du Fragen hast.'),
  ('beitritt.abgelehnt.text','en','Contact the board of {verein} if you have any questions.'),
  ('beitritt.abgelehnt.text','es','Si tienes dudas, ponte en contacto con la directiva de {verein}.'),
  ('beitritt.abgelehnt.text','pt','{verein}: se tiveres dúvidas, fala com a direção.'),
  ('beitritt.abgelehnt.text','it','{verein}: se hai domande, rivolgiti alla dirigenza.'),
  ('beitritt.abgelehnt.text','tr','Soruların varsa {verein} yönetimiyle iletişime geç.'),
  ('beitritt.abgelehnt.text','fr','Contacte la direction de {verein} si tu as des questions.'),
  ('allg.deinVerein','de','deinem Verein'),
  ('allg.deinVerein','en','your club'),
  ('allg.deinVerein','es','tu club'),
  ('allg.deinVerein','pt','O teu clube'),
  ('allg.deinVerein','it','La tua società'),
  ('allg.deinVerein','tr','kulübünün'),
  ('allg.deinVerein','fr','ton club'),
  ('chat.titel','de','Neue Nachricht'),
  ('chat.titel','en','New message'),
  ('chat.titel','es','Nuevo mensaje'),
  ('chat.titel','pt','Nova mensagem'),
  ('chat.titel','it','Nuovo messaggio'),
  ('chat.titel','tr','Yeni mesaj'),
  ('chat.titel','fr','Nouveau message'),
  ('allg.jemand','de','Jemand'),
  ('allg.jemand','en','Someone'),
  ('allg.jemand','es','Alguien'),
  ('allg.jemand','pt','Um sócio'),
  ('allg.jemand','it','Qualcuno'),
  ('allg.jemand','tr','Biri'),
  ('allg.jemand','fr','Quelqu''un'),
  ('aufgaben.schwelle.titel','de','Der Verein braucht Unterstützung'),
  ('aufgaben.schwelle.titel','en','The club needs a hand'),
  ('aufgaben.schwelle.titel','es','El club necesita tu ayuda'),
  ('aufgaben.schwelle.titel','pt','O clube precisa de ti'),
  ('aufgaben.schwelle.titel','it','La società ha bisogno di te'),
  ('aufgaben.schwelle.titel','tr','Kulübün desteğe ihtiyacı var'),
  ('aufgaben.schwelle.titel','fr','Le club a besoin d''aide'),
  ('aufgaben.schwelle.text','de','Schon 70 % der Mitglieder haben sich für Aufgaben eingetragen. Hilfst du auch mit?'),
  ('aufgaben.schwelle.text','en','70% of members have already signed up for tasks. Will you join in?'),
  ('aufgaben.schwelle.text','es','El 70 % de los socios ya se ha apuntado a alguna tarea. ¿Te apuntas tú también?'),
  ('aufgaben.schwelle.text','pt','Já 70 % dos sócios se inscreveram em tarefas. E tu, também ajudas?'),
  ('aufgaben.schwelle.text','it','Il 70% dei soci si è già iscritto alle attività. Dai una mano anche tu?'),
  ('aufgaben.schwelle.text','tr','Üyelerin %70''i çoktan görev aldı. Sen de yardım eder misin?'),
  ('aufgaben.schwelle.text','fr','Déjà 70 % des membres se sont inscrits pour une tâche. Et toi, tu participes ?'),
  ('fahrzeug.titel','de','Vereinsfahrzeug'),
  ('fahrzeug.titel','en','Club vehicle'),
  ('fahrzeug.titel','es','Vehículo del club'),
  ('fahrzeug.titel','pt','Veículo do clube'),
  ('fahrzeug.titel','it','Veicolo della società'),
  ('fahrzeug.titel','tr','Kulüp aracı'),
  ('fahrzeug.titel','fr','Véhicule du club'),
  ('fahrzeug.angenommen','de','Deine Anfrage zur Buchung des Vereinsfahrzeugs wurde angenommen.'),
  ('fahrzeug.angenommen','en','Your request to book the club vehicle was approved.'),
  ('fahrzeug.angenommen','es','Se ha aceptado tu solicitud de reserva del vehículo del club.'),
  ('fahrzeug.angenommen','pt','O teu pedido de reserva do veículo do clube foi aceite.'),
  ('fahrzeug.angenommen','it','La tua richiesta di prenotazione del veicolo della società è stata accettata.'),
  ('fahrzeug.angenommen','tr','Kulüp aracı için yaptığın rezervasyon talebi onaylandı.'),
  ('fahrzeug.angenommen','fr','Ta demande de réservation du véhicule a été acceptée.'),
  ('fahrzeug.abgelehnt','de','Deine Anfrage zur Buchung des Vereinsfahrzeugs wurde abgelehnt.'),
  ('fahrzeug.abgelehnt','en','Your request to book the club vehicle was declined.'),
  ('fahrzeug.abgelehnt','es','Se ha rechazado tu solicitud de reserva del vehículo del club.'),
  ('fahrzeug.abgelehnt','pt','O teu pedido de reserva do veículo do clube foi recusado.'),
  ('fahrzeug.abgelehnt','it','La tua richiesta di prenotazione del veicolo della società è stata rifiutata.'),
  ('fahrzeug.abgelehnt','tr','Kulüp aracı için yaptığın rezervasyon talebi reddedildi.'),
  ('fahrzeug.abgelehnt','fr','Ta demande de réservation du véhicule a été refusée.'),
  ('fahrzeug.anfrage.titel','de','Neue Buchungsanfrage für das Vereinsfahrzeug'),
  ('fahrzeug.anfrage.titel','en','New vehicle booking request'),
  ('fahrzeug.anfrage.titel','es','Nueva solicitud de reserva del vehículo'),
  ('fahrzeug.anfrage.titel','pt','Novo pedido de reserva do veículo'),
  ('fahrzeug.anfrage.titel','it','Nuova richiesta per il veicolo'),
  ('fahrzeug.anfrage.titel','tr','Kulüp aracı için yeni talep'),
  ('fahrzeug.anfrage.titel','fr','Nouvelle demande de réservation'),
  ('fahrzeug.anfrage.text','de','Neue Buchungsanfrage für das Vereinsfahrzeug von {wer}.'),
  ('fahrzeug.anfrage.text','en','New booking request for the club vehicle from {wer}.'),
  ('fahrzeug.anfrage.text','es','Nueva solicitud de reserva del vehículo del club por parte de {wer}.'),
  ('fahrzeug.anfrage.text','pt','{wer} quer reservar o veículo do clube.'),
  ('fahrzeug.anfrage.text','it','Nuova richiesta di prenotazione del veicolo della società da parte di {wer}.'),
  ('fahrzeug.anfrage.text','tr','{wer} kulüp aracı için yeni bir rezervasyon talebi gönderdi.'),
  ('fahrzeug.anfrage.text','fr','Nouvelle demande de réservation du véhicule du club par {wer}.'),
  ('allg.einMitglied','de','einem Mitglied'),
  ('allg.einMitglied','en','a member'),
  ('allg.einMitglied','es','un socio'),
  ('allg.einMitglied','pt','Um sócio'),
  ('allg.einMitglied','it','un socio'),
  ('allg.einMitglied','tr','Bir üye'),
  ('allg.einMitglied','fr','un membre'),
  ('fahrzeug.storniert.titel','de','Fahrzeugbuchung storniert'),
  ('fahrzeug.storniert.titel','en','Vehicle booking cancelled'),
  ('fahrzeug.storniert.titel','es','Reserva de vehículo cancelada'),
  ('fahrzeug.storniert.titel','pt','Reserva de veículo cancelada'),
  ('fahrzeug.storniert.titel','it','Prenotazione veicolo annullata'),
  ('fahrzeug.storniert.titel','tr','Araç rezervasyonu iptal edildi'),
  ('fahrzeug.storniert.titel','fr','Réservation de véhicule annulée'),
  ('fahrzeug.storniert.text','de','Eine deiner Fahrzeugbuchungen wurde storniert.'),
  ('fahrzeug.storniert.text','en','One of your vehicle bookings was cancelled.'),
  ('fahrzeug.storniert.text','es','Se ha cancelado una de tus reservas de vehículo.'),
  ('fahrzeug.storniert.text','pt','Uma das tuas reservas de veículo foi cancelada.'),
  ('fahrzeug.storniert.text','it','Una delle tue prenotazioni del veicolo è stata annullata.'),
  ('fahrzeug.storniert.text','tr','Bir araç rezervasyonun iptal edildi.'),
  ('fahrzeug.storniert.text','fr','Une de tes réservations de véhicule a été annulée.'),
  ('ergebnis.fehlt.titel','de','Ergebnis fehlt'),
  ('ergebnis.fehlt.titel','en','Result missing'),
  ('ergebnis.fehlt.titel','es','Falta el resultado'),
  ('ergebnis.fehlt.titel','pt','Falta o resultado'),
  ('ergebnis.fehlt.titel','it','Risultato mancante'),
  ('ergebnis.fehlt.titel','tr','Sonuç eksik'),
  ('ergebnis.fehlt.titel','fr','Résultat manquant'),
  ('ergebnis.fehlt.text','de','Bitte das Ergebnis vom Spiel {titel} eintragen.'),
  ('ergebnis.fehlt.text','en','{titel}: please enter the match result.'),
  ('ergebnis.fehlt.text','es','Introduce el resultado del partido {titel}.'),
  ('ergebnis.fehlt.text','pt','Regista o resultado: {titel}.'),
  ('ergebnis.fehlt.text','it','{titel}: inserisci il risultato.'),
  ('ergebnis.fehlt.text','tr','{titel} sonucu henüz girilmedi. Lütfen ekle.'),
  ('ergebnis.fehlt.text','fr','N''oublie pas de saisir le résultat de « {titel} ».'),
  ('ergebnis.titel','de','Ergebnis'),
  ('ergebnis.titel','en','Result'),
  ('ergebnis.titel','es','Resultado'),
  ('ergebnis.titel','pt','Resultado'),
  ('ergebnis.titel','it','Risultato'),
  ('ergebnis.titel','tr','Sonuç'),
  ('ergebnis.titel','fr','Résultat'),
  ('ergebnis.text','de','{titel}: {heim}:{auswaerts}'),
  ('ergebnis.text','en','{titel}: {heim}:{auswaerts}'),
  ('ergebnis.text','es','{titel}: {heim}:{auswaerts}'),
  ('ergebnis.text','pt','{titel}: {heim}:{auswaerts}'),
  ('ergebnis.text','it','{titel}: {heim}:{auswaerts}'),
  ('ergebnis.text','tr','{titel}: {heim}:{auswaerts}'),
  ('ergebnis.text','fr','{titel} : {heim}:{auswaerts}'),
  ('tipp.titel','de','Das Ergebnis steht fest – deine Punkte sind berechnet.'),
  ('tipp.titel','en','Result is in – your points are ready'),
  ('tipp.titel','es','Resultado final: ya tienes tus puntos.'),
  ('tipp.titel','pt','Resultado final: já tens os teus pontos'),
  ('tipp.titel','it','Risultato ufficiale: ecco i tuoi punti'),
  ('tipp.titel','tr','Sonuç belli, puanların hesaplandı'),
  ('tipp.titel','fr','Résultat final : tes points sont calculés.'),
  ('tipp.text','de','{titel} · {heim}:{auswaerts}'),
  ('tipp.text','en','{titel} · {heim}:{auswaerts}'),
  ('tipp.text','es','{titel} · {heim}:{auswaerts}'),
  ('tipp.text','pt','{titel} · {heim}:{auswaerts}'),
  ('tipp.text','it','{titel} · {heim}:{auswaerts}'),
  ('tipp.text','tr','{titel} · {heim}:{auswaerts}'),
  ('tipp.text','fr','{titel} · {heim}:{auswaerts}'),
  ('allg.begegnung','de','Begegnung'),
  ('allg.begegnung','en','Match'),
  ('allg.begegnung','es','Encuentro'),
  ('allg.begegnung','pt','Encontro'),
  ('allg.begegnung','it','Incontro'),
  ('allg.begegnung','tr','Karşılaşma'),
  ('allg.begegnung','fr','Rencontre'),
  ('allg.verein','de','Verein'),
  ('allg.verein','en','Your club'),
  ('allg.verein','es','Club'),
  ('allg.verein','pt','Clube'),
  ('allg.verein','it','La società'),
  ('allg.verein','tr','Kulüp'),
  ('allg.verein','fr','Club'),
  ('ergebnis.heim.gewonnen','de','{verein}: Das Heimspiel der {mannschaft} haben wir mit {heim}:{auswaerts} gewonnen!'),
  ('ergebnis.heim.gewonnen','en','{verein}: We won the {mannschaft} home match {heim}:{auswaerts}!'),
  ('ergebnis.heim.gewonnen','es','{verein}: ¡Hemos ganado el partido de {mannschaft} en casa por {heim}:{auswaerts}!'),
  ('ergebnis.heim.gewonnen','pt','{verein}: a nossa equipa {mannschaft} ganhou em casa por {heim}:{auswaerts}!'),
  ('ergebnis.heim.gewonnen','it','{verein}: la nostra {mannschaft} vince in casa per {heim}:{auswaerts}!'),
  ('ergebnis.heim.gewonnen','tr','{verein}: {mannschaft} takımımız iç saha maçını {heim}:{auswaerts} kazandı!'),
  ('ergebnis.heim.gewonnen','fr','{verein} : victoire à domicile de notre équipe {mannschaft}, {heim}:{auswaerts} !'),
  ('ergebnis.heim.unentschieden','de','{verein}: Das Heimspiel der {mannschaft} geht mit einem {heim}:{auswaerts} unentschieden aus!'),
  ('ergebnis.heim.unentschieden','en','{verein}: The {mannschaft} home match ended in a {heim}:{auswaerts} draw!'),
  ('ergebnis.heim.unentschieden','es','{verein}: ¡El partido de {mannschaft} en casa acaba en empate {heim}:{auswaerts}!'),
  ('ergebnis.heim.unentschieden','pt','{verein}: a nossa equipa {mannschaft} empatou em casa por {heim}:{auswaerts}!'),
  ('ergebnis.heim.unentschieden','it','{verein}: la nostra {mannschaft} pareggia in casa per {heim}:{auswaerts}!'),
  ('ergebnis.heim.unentschieden','tr','{verein}: {mannschaft} takımımızın iç saha maçı {heim}:{auswaerts} berabere bitti!'),
  ('ergebnis.heim.unentschieden','fr','{verein} : match nul à domicile pour notre équipe {mannschaft}, {heim}:{auswaerts} !'),
  ('ergebnis.heim.verloren','de','{verein}: Das Heimspiel der {mannschaft} haben wir mit {auswaerts}:{heim} verloren!'),
  ('ergebnis.heim.verloren','en','{verein}: We lost the {mannschaft} home match {auswaerts}:{heim}!'),
  ('ergebnis.heim.verloren','es','{verein}: ¡Hemos perdido el partido de {mannschaft} en casa por {auswaerts}:{heim}!'),
  ('ergebnis.heim.verloren','pt','{verein}: a nossa equipa {mannschaft} perdeu em casa por {auswaerts}:{heim}!'),
  ('ergebnis.heim.verloren','it','{verein}: la nostra {mannschaft} perde in casa per {auswaerts}:{heim}.'),
  ('ergebnis.heim.verloren','tr','{verein}: {mannschaft} takımımız iç saha maçını {auswaerts}:{heim} kaybetti!'),
  ('ergebnis.heim.verloren','fr','{verein} : défaite à domicile de notre équipe {mannschaft}, {auswaerts}:{heim} !'),
  ('ergebnis.auswaerts.gewonnen','de','{verein}: Das Auswärtsspiel der {mannschaft} haben wir mit {heim}:{auswaerts} gewonnen!'),
  ('ergebnis.auswaerts.gewonnen','en','{verein}: We won the {mannschaft} away match {heim}:{auswaerts}!'),
  ('ergebnis.auswaerts.gewonnen','es','{verein}: ¡Hemos ganado el partido de {mannschaft} fuera de casa por {heim}:{auswaerts}!'),
  ('ergebnis.auswaerts.gewonnen','pt','{verein}: a nossa equipa {mannschaft} ganhou fora por {heim}:{auswaerts}!'),
  ('ergebnis.auswaerts.gewonnen','it','{verein}: la nostra {mannschaft} vince in trasferta per {heim}:{auswaerts}!'),
  ('ergebnis.auswaerts.gewonnen','tr','{verein}: {mannschaft} takımımız deplasman maçını {heim}:{auswaerts} kazandı!'),
  ('ergebnis.auswaerts.gewonnen','fr','{verein} : victoire à l''extérieur de notre équipe {mannschaft}, {heim}:{auswaerts} !'),
  ('ergebnis.auswaerts.unentschieden','de','{verein}: Das Auswärtsspiel der {mannschaft} geht mit einem {heim}:{auswaerts} unentschieden aus!'),
  ('ergebnis.auswaerts.unentschieden','en','{verein}: The {mannschaft} away match ended in a {heim}:{auswaerts} draw!'),
  ('ergebnis.auswaerts.unentschieden','es','{verein}: ¡El partido de {mannschaft} fuera de casa acaba en empate {heim}:{auswaerts}!'),
  ('ergebnis.auswaerts.unentschieden','pt','{verein}: a nossa equipa {mannschaft} empatou fora por {heim}:{auswaerts}!'),
  ('ergebnis.auswaerts.unentschieden','it','{verein}: la nostra {mannschaft} pareggia in trasferta per {heim}:{auswaerts}!'),
  ('ergebnis.auswaerts.unentschieden','tr','{verein}: {mannschaft} takımımızın deplasman maçı {heim}:{auswaerts} berabere bitti!'),
  ('ergebnis.auswaerts.unentschieden','fr','{verein} : match nul à l''extérieur pour notre équipe {mannschaft}, {heim}:{auswaerts} !'),
  ('ergebnis.auswaerts.verloren','de','{verein}: Das Auswärtsspiel der {mannschaft} haben wir mit {auswaerts}:{heim} verloren!'),
  ('ergebnis.auswaerts.verloren','en','{verein}: We lost the {mannschaft} away match {auswaerts}:{heim}!'),
  ('ergebnis.auswaerts.verloren','es','{verein}: ¡Hemos perdido el partido de {mannschaft} fuera de casa por {auswaerts}:{heim}!'),
  ('ergebnis.auswaerts.verloren','pt','{verein}: a nossa equipa {mannschaft} perdeu fora por {auswaerts}:{heim}!'),
  ('ergebnis.auswaerts.verloren','it','{verein}: la nostra {mannschaft} perde in trasferta per {auswaerts}:{heim}.'),
  ('ergebnis.auswaerts.verloren','tr','{verein}: {mannschaft} takımımız deplasman maçını {auswaerts}:{heim} kaybetti!'),
  ('ergebnis.auswaerts.verloren','fr','{verein} : défaite à l''extérieur de notre équipe {mannschaft}, {auswaerts}:{heim} !'),
  ('news.titel','de','Neue Vereins-News'),
  ('news.titel','en','New club news'),
  ('news.titel','es','Nuevas noticias del club'),
  ('news.titel','pt','Novas notícias do clube'),
  ('news.titel','it','Nuove notizie della società'),
  ('news.titel','tr','Yeni kulüp haberi'),
  ('news.titel','fr','Nouvelle actualité du club'),
  ('news.text','de','Neue News. Jetzt lesen!'),
  ('news.text','en','A new post is online. Read it now!'),
  ('news.text','es','Hay noticias nuevas. ¡Léelas ya!'),
  ('news.text','pt','Há novidades. Vem ler!'),
  ('news.text','it','C''è una nuova notizia. Leggila subito!'),
  ('news.text','tr','Yeni bir haber var. Hemen oku!'),
  ('news.text','fr','Nouvelle actualité. À lire maintenant !'),
  ('fahrgemeinschaft.neu.titel','de','Neuer Mitfahrer'),
  ('fahrgemeinschaft.neu.titel','en','New passenger'),
  ('fahrgemeinschaft.neu.titel','es','Nuevo pasajero'),
  ('fahrgemeinschaft.neu.titel','pt','Novo passageiro'),
  ('fahrgemeinschaft.neu.titel','it','Nuovo passeggero'),
  ('fahrgemeinschaft.neu.titel','tr','Yeni yolcu'),
  ('fahrgemeinschaft.neu.titel','fr','Nouveau passager'),
  ('fahrgemeinschaft.neu.text','de','{wer} ist deiner Fahrgemeinschaft beigetreten.'),
  ('fahrgemeinschaft.neu.text','en','{wer} joined your carpool.'),
  ('fahrgemeinschaft.neu.text','es','{wer} se ha unido a tu viaje compartido.'),
  ('fahrgemeinschaft.neu.text','pt','{wer} juntou-se à tua boleia.'),
  ('fahrgemeinschaft.neu.text','it','{wer} ha prenotato un posto nel tuo viaggio condiviso.'),
  ('fahrgemeinschaft.neu.text','tr','{wer} sunduğun araç paylaşımına katıldı.'),
  ('fahrgemeinschaft.neu.text','fr','{wer} a rejoint ton covoiturage.'),
  ('fahrgemeinschaft.fehlt.titel','de','Noch keine Fahrgemeinschaft'),
  ('fahrgemeinschaft.fehlt.titel','en','No carpool yet'),
  ('fahrgemeinschaft.fehlt.titel','es','Aún no hay viaje compartido'),
  ('fahrgemeinschaft.fehlt.titel','pt','Ainda sem boleia'),
  ('fahrgemeinschaft.fehlt.titel','it','Nessun viaggio condiviso'),
  ('fahrgemeinschaft.fehlt.titel','tr','Henüz araç paylaşımı yok'),
  ('fahrgemeinschaft.fehlt.titel','fr','Pas encore de covoiturage'),
  ('fahrgemeinschaft.fehlt.text','de','Für „{titel}“ am {datum} gibt es noch keine Fahrgemeinschaft. Biete jetzt einen Platz an!'),
  ('fahrgemeinschaft.fehlt.text','en','There is no carpool yet for “{titel}” on {datum}. Offer a seat now!'),
  ('fahrgemeinschaft.fehlt.text','es','Para “{titel}” el {datum} aún no hay viaje compartido. ¡Ofrece una plaza!'),
  ('fahrgemeinschaft.fehlt.text','pt','Ainda não há boleia para «{titel}» no dia {datum}. Oferece já um lugar!'),
  ('fahrgemeinschaft.fehlt.text','it','Per “{titel}” del {datum} non c''è ancora un viaggio condiviso. Offri un posto!'),
  ('fahrgemeinschaft.fehlt.text','tr','{datum} tarihindeki “{titel}” için henüz araç paylaşımı yok. Hemen bir yer sun!'),
  ('fahrgemeinschaft.fehlt.text','fr','Aucun covoiturage pour « {titel} » le {datum}. Propose une place !'),
  ('termin.training.angelegt.titel','de','Training angelegt'),
  ('termin.training.angelegt.titel','en','Training created'),
  ('termin.training.angelegt.titel','es','Entrenamiento creado'),
  ('termin.training.angelegt.titel','pt','Treino criado'),
  ('termin.training.angelegt.titel','it','Allenamento creato'),
  ('termin.training.angelegt.titel','tr','Antrenman oluşturuldu'),
  ('termin.training.angelegt.titel','fr','Entraînement créé'),
  ('termin.training.angelegt.text','de','Das Training wurde angelegt.'),
  ('termin.training.angelegt.text','en','The training has been created.'),
  ('termin.training.angelegt.text','es','Se ha creado el entrenamiento.'),
  ('termin.training.angelegt.text','pt','O treino foi criado.'),
  ('termin.training.angelegt.text','it','L''allenamento è stato creato.'),
  ('termin.training.angelegt.text','tr','Takvime yeni bir antrenman eklendi.'),
  ('termin.training.angelegt.text','fr','L''entraînement a été créé.'),
  ('termin.training.abgesagt.titel','de','Training abgesagt'),
  ('termin.training.abgesagt.titel','en','Training cancelled'),
  ('termin.training.abgesagt.titel','es','Entrenamiento cancelado'),
  ('termin.training.abgesagt.titel','pt','Treino cancelado'),
  ('termin.training.abgesagt.titel','it','Allenamento annullato'),
  ('termin.training.abgesagt.titel','tr','Antrenman iptal edildi'),
  ('termin.training.abgesagt.titel','fr','Entraînement annulé'),
  ('termin.training.abgesagt.text','de','Das Training wurde abgesagt.'),
  ('termin.training.abgesagt.text','en','The training has been cancelled.'),
  ('termin.training.abgesagt.text','es','Se ha cancelado el entrenamiento.'),
  ('termin.training.abgesagt.text','pt','O treino foi cancelado.'),
  ('termin.training.abgesagt.text','it','L''allenamento è stato annullato.'),
  ('termin.training.abgesagt.text','tr','Planlanan antrenman takvimden kaldırıldı.'),
  ('termin.training.abgesagt.text','fr','L''entraînement a été annulé.'),
  ('termin.training.geaendert.titel','de','Training geändert'),
  ('termin.training.geaendert.titel','en','Training changed'),
  ('termin.training.geaendert.titel','es','Entrenamiento modificado'),
  ('termin.training.geaendert.titel','pt','Treino alterado'),
  ('termin.training.geaendert.titel','it','Allenamento modificato'),
  ('termin.training.geaendert.titel','tr','Antrenman değişti'),
  ('termin.training.geaendert.titel','fr','Entraînement modifié'),
  ('termin.training.geaendert.text','de','Das Training wurde geändert.'),
  ('termin.training.geaendert.text','en','The training has been changed.'),
  ('termin.training.geaendert.text','es','Se ha modificado el entrenamiento.'),
  ('termin.training.geaendert.text','pt','O treino foi alterado.'),
  ('termin.training.geaendert.text','it','L''allenamento è stato modificato.'),
  ('termin.training.geaendert.text','tr','Antrenman bilgileri güncellendi.'),
  ('termin.training.geaendert.text','fr','L''entraînement a été modifié.'),
  ('termin.spiel.angelegt.titel','de','Spiel angelegt'),
  ('termin.spiel.angelegt.titel','en','Match created'),
  ('termin.spiel.angelegt.titel','es','Partido creado'),
  ('termin.spiel.angelegt.titel','pt','Jogo criado'),
  ('termin.spiel.angelegt.titel','it','Partita creata'),
  ('termin.spiel.angelegt.titel','tr','Maç oluşturuldu'),
  ('termin.spiel.angelegt.titel','fr','Match créé'),
  ('termin.spiel.angelegt.text','de','Das Spiel wurde angelegt.'),
  ('termin.spiel.angelegt.text','en','The match has been created.'),
  ('termin.spiel.angelegt.text','es','Se ha creado el partido.'),
  ('termin.spiel.angelegt.text','pt','O jogo foi criado.'),
  ('termin.spiel.angelegt.text','it','La partita è stata creata.'),
  ('termin.spiel.angelegt.text','tr','Takvime yeni bir maç eklendi.'),
  ('termin.spiel.angelegt.text','fr','Le match a été créé.'),
  ('termin.spiel.abgesagt.titel','de','Spiel abgesagt'),
  ('termin.spiel.abgesagt.titel','en','Match cancelled'),
  ('termin.spiel.abgesagt.titel','es','Partido cancelado'),
  ('termin.spiel.abgesagt.titel','pt','Jogo cancelado'),
  ('termin.spiel.abgesagt.titel','it','Partita annullata'),
  ('termin.spiel.abgesagt.titel','tr','Maç iptal edildi'),
  ('termin.spiel.abgesagt.titel','fr','Match annulé'),
  ('termin.spiel.abgesagt.text','de','Das Spiel wurde abgesagt.'),
  ('termin.spiel.abgesagt.text','en','The match has been cancelled.'),
  ('termin.spiel.abgesagt.text','es','Se ha cancelado el partido.'),
  ('termin.spiel.abgesagt.text','pt','O jogo foi cancelado.'),
  ('termin.spiel.abgesagt.text','it','La partita è stata annullata.'),
  ('termin.spiel.abgesagt.text','tr','Planlanan maç takvimden kaldırıldı.'),
  ('termin.spiel.abgesagt.text','fr','Le match a été annulé.'),
  ('termin.spiel.geaendert.titel','de','Spiel geändert'),
  ('termin.spiel.geaendert.titel','en','Match changed'),
  ('termin.spiel.geaendert.titel','es','Partido modificado'),
  ('termin.spiel.geaendert.titel','pt','Jogo alterado'),
  ('termin.spiel.geaendert.titel','it','Partita modificata'),
  ('termin.spiel.geaendert.titel','tr','Maç değişti'),
  ('termin.spiel.geaendert.titel','fr','Match modifié'),
  ('termin.spiel.geaendert.text','de','Das Spiel wurde geändert.'),
  ('termin.spiel.geaendert.text','en','The match has been changed.'),
  ('termin.spiel.geaendert.text','es','Se ha modificado el partido.'),
  ('termin.spiel.geaendert.text','pt','O jogo foi alterado.'),
  ('termin.spiel.geaendert.text','it','La partita è stata modificata.'),
  ('termin.spiel.geaendert.text','tr','Maç bilgileri güncellendi.'),
  ('termin.spiel.geaendert.text','fr','Le match a été modifié.'),
  ('termin.event.angelegt.titel','de','Termin angelegt'),
  ('termin.event.angelegt.titel','en','Event created'),
  ('termin.event.angelegt.titel','es','Evento creado'),
  ('termin.event.angelegt.titel','pt','Evento criado'),
  ('termin.event.angelegt.titel','it','Evento creato'),
  ('termin.event.angelegt.titel','tr','Etkinlik oluşturuldu'),
  ('termin.event.angelegt.titel','fr','Événement créé'),
  ('termin.event.angelegt.text','de','Der Termin wurde angelegt.'),
  ('termin.event.angelegt.text','en','The event has been created.'),
  ('termin.event.angelegt.text','es','Se ha creado el evento.'),
  ('termin.event.angelegt.text','pt','O evento foi criado.'),
  ('termin.event.angelegt.text','it','L''evento è stato creato.'),
  ('termin.event.angelegt.text','tr','Takvime yeni bir etkinlik eklendi.'),
  ('termin.event.angelegt.text','fr','L''événement a été créé.'),
  ('termin.event.abgesagt.titel','de','Termin abgesagt'),
  ('termin.event.abgesagt.titel','en','Event cancelled'),
  ('termin.event.abgesagt.titel','es','Evento cancelado'),
  ('termin.event.abgesagt.titel','pt','Evento cancelado'),
  ('termin.event.abgesagt.titel','it','Evento annullato'),
  ('termin.event.abgesagt.titel','tr','Etkinlik iptal edildi'),
  ('termin.event.abgesagt.titel','fr','Événement annulé'),
  ('termin.event.abgesagt.text','de','Der Termin wurde abgesagt.'),
  ('termin.event.abgesagt.text','en','The event has been cancelled.'),
  ('termin.event.abgesagt.text','es','Se ha cancelado el evento.'),
  ('termin.event.abgesagt.text','pt','O evento foi cancelado.'),
  ('termin.event.abgesagt.text','it','L''evento è stato annullato.'),
  ('termin.event.abgesagt.text','tr','Planlanan etkinlik takvimden kaldırıldı.'),
  ('termin.event.abgesagt.text','fr','L''événement a été annulé.'),
  ('termin.event.geaendert.titel','de','Termin geändert'),
  ('termin.event.geaendert.titel','en','Event changed'),
  ('termin.event.geaendert.titel','es','Evento modificado'),
  ('termin.event.geaendert.titel','pt','Evento alterado'),
  ('termin.event.geaendert.titel','it','Evento modificato'),
  ('termin.event.geaendert.titel','tr','Etkinlik değişti'),
  ('termin.event.geaendert.titel','fr','Événement modifié'),
  ('termin.event.geaendert.text','de','Der Termin wurde geändert.'),
  ('termin.event.geaendert.text','en','The event has been changed.'),
  ('termin.event.geaendert.text','es','Se ha modificado el evento.'),
  ('termin.event.geaendert.text','pt','O evento foi alterado.'),
  ('termin.event.geaendert.text','it','L''evento è stato modificato.'),
  ('termin.event.geaendert.text','tr','Etkinlik bilgileri güncellendi.'),
  ('termin.event.geaendert.text','fr','L''événement a été modifié.'),
  ('termin.grund','de',' Grund: {grund}'),
  ('termin.grund','en',' Reason: {grund}'),
  ('termin.grund','es',' Motivo: {grund}'),
  ('termin.grund','pt',' Motivo: {grund}'),
  ('termin.grund','it',' Motivo: {grund}'),
  ('termin.grund','tr',' Sebep: {grund}'),
  ('termin.grund','fr',' Motif : {grund}'),
  ('familie.titel','de','Familienverknüpfung'),
  ('familie.titel','en','Family link'),
  ('familie.titel','es','Vínculo familiar'),
  ('familie.titel','pt','Ligação familiar'),
  ('familie.titel','it','Collegamento familiare'),
  ('familie.titel','tr','Aile bağlantısı'),
  ('familie.titel','fr','Lien familial'),
  ('familie.text','de','Eine Familienverknüpfung wurde für dich hinterlegt.'),
  ('familie.text','en','A family link has been added to your profile.'),
  ('familie.text','es','Se ha registrado un vínculo familiar para ti.'),
  ('familie.text','pt','Foi criada uma ligação familiar para ti.'),
  ('familie.text','it','È stato registrato un collegamento familiare per te.'),
  ('familie.text','tr','Senin için bir aile bağlantısı oluşturuldu.'),
  ('familie.text','fr','Un lien familial a été enregistré pour toi.'),
  ('strafe.neu.titel','de','Neue Strafe'),
  ('strafe.neu.titel','en','New penalty'),
  ('strafe.neu.titel','es','Nueva sanción'),
  ('strafe.neu.titel','pt','Nova sanção'),
  ('strafe.neu.titel','it','Nuova sanzione'),
  ('strafe.neu.titel','tr','Yeni ceza'),
  ('strafe.neu.titel','fr','Nouvelle sanction'),
  ('strafe.neu.text','de','{regel} wurde dir zugewiesen.'),
  ('strafe.neu.text','en','{regel} was assigned to you.'),
  ('strafe.neu.text','es','{regel}: se te ha asignado.'),
  ('strafe.neu.text','pt','{regel} está agora na tua conta.'),
  ('strafe.neu.text','it','{regel}: ora è a tuo carico.'),
  ('strafe.neu.text','tr','{regel} sana yazıldı.'),
  ('strafe.neu.text','fr','Tu as reçu une sanction : {regel}.'),
  ('strafe.bezahlt.titel','de','Strafe bezahlt'),
  ('strafe.bezahlt.titel','en','Penalty paid'),
  ('strafe.bezahlt.titel','es','Sanción pagada'),
  ('strafe.bezahlt.titel','pt','Sanção paga'),
  ('strafe.bezahlt.titel','it','Sanzione pagata'),
  ('strafe.bezahlt.titel','tr','Ceza ödendi'),
  ('strafe.bezahlt.titel','fr','Sanction payée'),
  ('strafe.bezahlt.text','de','{regel} wurde als bezahlt bestätigt.'),
  ('strafe.bezahlt.text','en','{regel} was confirmed as paid.'),
  ('strafe.bezahlt.text','es','{regel}: pago confirmado.'),
  ('strafe.bezahlt.text','pt','{regel}: pagamento confirmado.'),
  ('strafe.bezahlt.text','it','{regel}: pagamento confermato.'),
  ('strafe.bezahlt.text','tr','{regel} ödenmiş olarak onaylandı.'),
  ('strafe.bezahlt.text','fr','Paiement confirmé : {regel}.'),
  ('strafe.zurueck.titel','de','Strafe zurückgezogen'),
  ('strafe.zurueck.titel','en','Penalty withdrawn'),
  ('strafe.zurueck.titel','es','Sanción retirada'),
  ('strafe.zurueck.titel','pt','Sanção retirada'),
  ('strafe.zurueck.titel','it','Sanzione ritirata'),
  ('strafe.zurueck.titel','tr','Ceza geri alındı'),
  ('strafe.zurueck.titel','fr','Sanction retirée'),
  ('strafe.zurueck.text','de','{regel} wurde gelöscht.'),
  ('strafe.zurueck.text','en','{regel} was deleted.'),
  ('strafe.zurueck.text','es','{regel} se ha eliminado.'),
  ('strafe.zurueck.text','pt','{regel} já não conta.'),
  ('strafe.zurueck.text','it','{regel}: non è più a tuo carico.'),
  ('strafe.zurueck.text','tr','{regel} silindi.'),
  ('strafe.zurueck.text','fr','Sanction annulée : {regel}.'),
  ('team.willkommen.titel','de','Willkommen im Team'),
  ('team.willkommen.titel','en','Welcome to the team'),
  ('team.willkommen.titel','es','Te damos la bienvenida al equipo'),
  ('team.willkommen.titel','pt','Boas-vindas à equipa'),
  ('team.willkommen.titel','it','Ti diamo il benvenuto in squadra'),
  ('team.willkommen.titel','tr','Takıma hoş geldin'),
  ('team.willkommen.titel','fr','Bienvenue dans l''équipe'),
  ('team.willkommen.text','de','Du wurdest der Mannschaft „{team}“ hinzugefügt.'),
  ('team.willkommen.text','en','You have been added to the team “{team}”.'),
  ('team.willkommen.text','es','Se te ha añadido al equipo “{team}”.'),
  ('team.willkommen.text','pt','Já fazes parte da equipa «{team}».'),
  ('team.willkommen.text','it','Ora fai parte della squadra “{team}”.'),
  ('team.willkommen.text','tr','“{team}” takımına eklendin.'),
  ('team.willkommen.text','fr','Tu fais maintenant partie de l''équipe « {team} ».'),
  ('geburtstag.titel','de','Heute Geburtstag 🎉'),
  ('geburtstag.titel','en','Birthday today 🎉'),
  ('geburtstag.titel','es','Cumpleaños hoy 🎉'),
  ('geburtstag.titel','pt','Aniversário hoje 🎉'),
  ('geburtstag.titel','it','Compleanno oggi 🎉'),
  ('geburtstag.titel','tr','Bugün doğum günü 🎉'),
  ('geburtstag.titel','fr','Anniversaire aujourd''hui 🎉'),
  ('geburtstag.text','de','{wer} hat heute Geburtstag!'),
  ('geburtstag.text','en','{wer} is celebrating a birthday today!'),
  ('geburtstag.text','es','¡{wer} cumple años hoy!'),
  ('geburtstag.text','pt','{wer} faz anos hoje!'),
  ('geburtstag.text','it','{wer} compie gli anni oggi!'),
  ('geburtstag.text','tr','{wer} bugün doğum gününü kutluyor!'),
  ('geburtstag.text','fr','{wer} fête son anniversaire aujourd''hui !'),
  ('helfer.gesucht.titel','de','Helfer gesucht'),
  ('helfer.gesucht.titel','en','Volunteers needed'),
  ('helfer.gesucht.titel','es','Se buscan voluntarios'),
  ('helfer.gesucht.titel','pt','Procuram-se voluntários'),
  ('helfer.gesucht.titel','it','Cercasi volontari'),
  ('helfer.gesucht.titel','tr','Gönüllü aranıyor'),
  ('helfer.gesucht.titel','fr','Bénévoles recherchés'),
  ('helfer.gesucht.text','de','Für „{titel}“ am {datum} werden noch Helfer gebraucht.'),
  ('helfer.gesucht.text','en','Volunteers are still needed for “{titel}” on {datum}.'),
  ('helfer.gesucht.text','es','Aún faltan voluntarios para “{titel}” el {datum}.'),
  ('helfer.gesucht.text','pt','Ainda faltam voluntários para «{titel}» no dia {datum}.'),
  ('helfer.gesucht.text','it','Per “{titel}” del {datum} servono ancora volontari.'),
  ('helfer.gesucht.text','tr','{datum} tarihindeki “{titel}” için hâlâ gönüllü gerekiyor.'),
  ('helfer.gesucht.text','fr','Il manque encore des bénévoles pour « {titel} » le {datum}.'),
  ('helfer.faellig.titel','de','Erinnerung: Helferaufgabe'),
  ('helfer.faellig.titel','en','Reminder: your duty'),
  ('helfer.faellig.titel','es','Recordatorio: turno de voluntario'),
  ('helfer.faellig.titel','pt','Lembrete: turno de voluntário'),
  ('helfer.faellig.titel','it','Promemoria: turno'),
  ('helfer.faellig.titel','tr','Hatırlatma: gönüllü görevi'),
  ('helfer.faellig.titel','fr','Rappel : permanence'),
  ('helfer.faellig.text','de','Deine Aufgabe „{titel}“ ist morgen fällig.'),
  ('helfer.faellig.text','en','Your duty “{titel}” is due tomorrow.'),
  ('helfer.faellig.text','es','Tu tarea “{titel}” vence mañana.'),
  ('helfer.faellig.text','pt','A tua tarefa «{titel}» é amanhã.'),
  ('helfer.faellig.text','it','Il tuo turno “{titel}” è domani.'),
  ('helfer.faellig.text','tr','“{titel}” görevin yarın seni bekliyor.'),
  ('helfer.faellig.text','fr','Ta permanence « {titel} » est prévue demain.'),
  ('sponsor.titel','de','Ein neuer Sponsor präsentiert sich'),
  ('sponsor.titel','en','Meet our new sponsor'),
  ('sponsor.titel','es','Un nuevo patrocinador se presenta'),
  ('sponsor.titel','pt','Um novo patrocinador apresenta-se'),
  ('sponsor.titel','it','Un nuovo sponsor si presenta'),
  ('sponsor.titel','tr','Yeni bir sponsor tanıtılıyor'),
  ('sponsor.titel','fr','Un nouveau sponsor se présente'),
  ('allg.vereinsmeldung','de','Vereinsmeldung'),
  ('allg.vereinsmeldung','en','Club update'),
  ('allg.vereinsmeldung','es','Aviso del club'),
  ('allg.vereinsmeldung','pt','Aviso do clube'),
  ('allg.vereinsmeldung','it','Comunicazione della società'),
  ('allg.vereinsmeldung','tr','Kulüp bildirimi'),
  ('allg.vereinsmeldung','fr','Info du club')
on conflict (schluessel, sprache) do update set text = excluded.text;

/* Ersatzsaetze fuer den Fall, dass der Name der Strafe fehlt. Eigene
   Saetze statt eines eingesetzten Wortes - sonst entsteht
   "Tu as reçu une sanction : Une sanction." */
insert into public.meldungstexte (schluessel, sprache, text) values
  ('strafe.neu.textOhneRegel','de','Dir wurde eine Strafe zugewiesen.'),
  ('strafe.neu.textOhneRegel','en','A penalty was assigned to you.'),
  ('strafe.neu.textOhneRegel','es','Se te ha asignado una sanción.'),
  ('strafe.neu.textOhneRegel','pt','Foi-te atribuída uma sanção.'),
  ('strafe.neu.textOhneRegel','it','Ti è stata assegnata una sanzione.'),
  ('strafe.neu.textOhneRegel','tr','Sana bir ceza yazıldı.'),
  ('strafe.neu.textOhneRegel','fr','Tu as reçu une sanction.'),
  ('strafe.bezahlt.textOhneRegel','de','Deine Strafe wurde als bezahlt bestätigt.'),
  ('strafe.bezahlt.textOhneRegel','en','Your penalty was confirmed as paid.'),
  ('strafe.bezahlt.textOhneRegel','es','Se ha confirmado el pago de tu sanción.'),
  ('strafe.bezahlt.textOhneRegel','pt','O pagamento da tua sanção foi confirmado.'),
  ('strafe.bezahlt.textOhneRegel','it','Il pagamento della tua sanzione è stato confermato.'),
  ('strafe.bezahlt.textOhneRegel','tr','Cezan ödenmiş olarak onaylandı.'),
  ('strafe.bezahlt.textOhneRegel','fr','Le paiement de ta sanction est confirmé.'),
  ('strafe.zurueck.textOhneRegel','de','Eine Strafe wurde gelöscht.'),
  ('strafe.zurueck.textOhneRegel','en','A penalty was deleted.'),
  ('strafe.zurueck.textOhneRegel','es','Se ha eliminado una de tus sanciones.'),
  ('strafe.zurueck.textOhneRegel','pt','Uma das tuas sanções foi eliminada.'),
  ('strafe.zurueck.textOhneRegel','it','Una sanzione è stata eliminata.'),
  ('strafe.zurueck.textOhneRegel','tr','Bir ceza silindi.'),
  ('strafe.zurueck.textOhneRegel','fr','Une de tes sanctions a été supprimée.')
on conflict (schluessel, sprache) do update set text = excluded.text;

-- ============================================================================
-- Gruppe 1: Ausloeser, die direkt in user_notifications schreiben.
-- Sie holen die Sprache ueber einen Verbund mit profiles - eine Zeile je
-- Empfaenger, jede in dessen Sprache.
-- ============================================================================

-- ------------------------------------------------------------------ Termine
create or replace function public.notify_event_audience()
 returns trigger language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_situation  text;   -- angelegt | abgesagt | geaendert
  v_basis      text;   -- z. B. termin.spiel.abgesagt
  v_schluessel text;   -- zugleich kind und Einstellungsschluessel
  v_teamart    text;   -- trainings | spiele | null
  v_grund      text;
begin
  v_teamart := case new.type when 'training' then 'trainings' when 'spiel' then 'spiele' else null end;

  /* Ein reiner Ergebniseintrag ist keine Aenderung des Termins - dafuer gibt
     es spielergebnis_melden. Sonst bekaeme der halbe Verein "Das Spiel wurde
     geaendert", sobald jemand 3:2 eintraegt. */
  if tg_op = 'UPDATE'
     and to_jsonb(old) - 'home_score' - 'away_score' - 'result_entered_at'
                       - 'result_entered_by' - 'updated_at' - 'ergebnis_erinnert_at'
       = to_jsonb(new) - 'home_score' - 'away_score' - 'result_entered_at'
                       - 'result_entered_by' - 'updated_at' - 'ergebnis_erinnert_at'
  then
    return new;
  end if;

  if tg_op = 'INSERT' then
    v_situation := 'angelegt';
    v_schluessel := case new.type when 'training' then 'training_created'
                                  when 'spiel'    then 'game_created'
                                  else 'events' end;
  elsif new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    v_situation := 'abgesagt';
    v_schluessel := case new.type when 'training' then 'training_cancelled'
                                  when 'spiel'    then 'game_cancelled'
                                  else 'events' end;
  elsif tg_op = 'UPDATE' then
    v_situation := 'geaendert';
    v_schluessel := case new.type when 'training' then 'training_changed'
                                  when 'spiel'    then 'game_changed'
                                  else 'events' end;
  else
    return new;
  end if;

  /* Ganze Saetze je Terminart, nicht "Das {art} wurde …" zusammengesetzt:
     Artikel und Geschlecht haengen in den meisten Sprachen am Wort. */
  v_basis := 'termin.' || case new.type when 'training' then 'training'
                                        when 'spiel'    then 'spiel'
                                        else 'event' end
             || '.' || v_situation;

  v_grund := nullif(trim(new.cancel_reason), '');

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  select distinct m.profile_id, new.club_id, v_schluessel,
         public.meldungstext(v_basis || '.titel', p.language),
         /* Der Grund steht am ENDE, nicht direkt hinter dem Satz. Vorher las
            sich eine Absage als "Das Spiel wurde abgesagt. Grund: Glatteis
            Herren 1 gegen Herringen · 12.09. · Hemberghalle" - der Grund
            klebte am Spieltitel und man wusste nicht, wo er aufhoert. */
         public.meldungstext(v_basis || '.text', p.language)
           || ' ' || coalesce(new.title, '')
           || coalesce(' · ' || to_char(new.starts_at, 'DD.MM. HH24:MI'), '')
           || coalesce(' · ' || new.location, '')
           || case when v_situation = 'abgesagt' and v_grund is not null
                   then ' ·' || public.meldungstext('termin.grund', p.language, jsonb_build_object('grund', v_grund))
                   else '' end,
         'termin', new.id
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  left join public.team_members tm
         on tm.membership_id = m.id and tm.team_id = new.team_id
  left join public.team_benachrichtigungen tb
         on tb.membership_id = m.id and tb.team_id = new.team_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and (new.team_id is null or tm.membership_id is not null or tb.aktiv)
    and public.team_meldung_erlaubt(m.id, new.team_id, v_teamart)
    and public.meldung_erlaubt(m.profile_id, v_schluessel);

  return new;
end;
$function$;

-- ------------------------------------------------------------ Spielergebnis
create or replace function public.spielergebnis_melden()
 returns trigger language plpgsql security definer set search_path to 'public'
as $function$
declare v_werte jsonb;
begin
  if new.home_score is null or new.away_score is null then return new; end if;
  if old.home_score is not distinct from new.home_score
     and old.away_score is not distinct from new.away_score then return new; end if;

  v_werte := jsonb_build_object('titel', coalesce(new.title, ''),
                                'heim', new.home_score, 'auswaerts', new.away_score);

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  select distinct m.profile_id, new.club_id, 'results',
         public.meldungstext('ergebnis.titel', p.language),
         public.meldungstext('ergebnis.text', p.language, v_werte),
         'termin', new.id
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  left join public.team_members tm
         on tm.membership_id = m.id and tm.team_id = new.team_id
  left join public.team_benachrichtigungen tb
         on tb.membership_id = m.id and tb.team_id = new.team_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and (new.team_id is null or tm.membership_id is not null or tb.aktiv)
    and public.team_meldung_erlaubt(m.id, new.team_id, 'ergebnisse')
    and public.meldung_erlaubt(m.profile_id, 'results');

  return new;
end;
$function$;

-- ----------------------------------------------------------------- Chat
--
-- Der Nachrichtentext selbst bleibt unangetastet - er ist das, was der
-- Absender geschrieben hat. Uebersetzt wird nur der Rahmen: der Ersatztitel,
-- wenn der Name des Absenders fehlt.
create or replace function public.chatnachricht_melden()
 returns trigger language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_club  uuid;
  v_team  uuid;
  v_wer   text;
  v_text  text;
begin
  select c.club_id, c.team_id into v_club, v_team from public.channels c where c.id = new.channel_id;
  if v_club is null then return new; end if;

  select display_name into v_wer from public.club_memberships where id = new.author_id;

  v_text := case when length(new.body) > 90 then left(new.body, 90) || ' …' else new.body end;

  insert into public.user_notifications (profile_id, club_id, kind, title, body)
  select distinct m.profile_id, v_club, 'chat',
         coalesce(v_wer, public.meldungstext('chat.titel', p.language)),
         coalesce(v_wer, public.meldungstext('allg.jemand', p.language)) || ': ' || v_text
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  left join public.team_members tm on tm.membership_id = m.id and tm.team_id = v_team
  where m.club_id = v_club and m.status = 'active' and m.profile_id is not null
    and m.id is distinct from new.author_id
    and (v_team is null or tm.membership_id is not null)
    and public.team_meldung_erlaubt(m.id, v_team, 'chat')
    and public.meldung_erlaubt(m.profile_id, 'chat');
  return new;
end;
$function$;

-- ----------------------------------------------------------- Vereins-News
create or replace function public.news_melden()
 returns trigger language plpgsql security definer set search_path to 'public'
as $function$
begin
  insert into public.user_notifications (profile_id, club_id, kind, title, body)
  select m.profile_id, new.club_id, 'news',
         public.meldungstext('news.titel', p.language),
         public.meldungstext('news.text', p.language)
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and m.profile_id is distinct from auth.uid()
    and public.meldung_erlaubt(m.profile_id, 'news');
  return new;
end;
$function$;

-- --------------------------------------------------------------- Aufgaben
create or replace function public.vereinsaufgabe_zuweisung_melden()
 returns trigger language plpgsql security definer set search_path to 'public'
as $function$
declare v_profil uuid; v_club uuid; v_titel text; v_wer text; v_sprache text;
begin
  select t.club_id, t.title into v_club, v_titel from public.club_tasks t where t.id = new.task_id;
  select profile_id into v_profil from public.club_memberships where id = new.membership_id;
  if v_profil is null or v_profil = auth.uid() then return new; end if;
  if not public.meldung_erlaubt(v_profil, 'tasks') then return new; end if;

  select display_name into v_wer from public.club_memberships
   where profile_id = auth.uid() and club_id = v_club limit 1;
  v_sprache := public.sprache_der_mitgliedschaft(new.membership_id);

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  values (v_profil, v_club, 'tasks',
          public.meldungstext('aufgabe.zugewiesen.titel', v_sprache),
          public.meldungstext('aufgabe.zugewiesen.textMitTitel', v_sprache,
            jsonb_build_object(
              'wer', coalesce(v_wer, public.meldungstext('allg.vereinsleitung', v_sprache)),
              'titel', coalesce(v_titel, ''))),
          'aufgabe', new.task_id);
  return new;
end;
$function$;

create or replace function public.aufgabe_zugewiesen_melden()
 returns trigger language plpgsql security definer set search_path to ''
as $function$
declare
  v_profil  uuid;
  v_wer     text;
  v_sprache text;
begin
  if new.assignee_membership_id is null then return new; end if;
  if tg_op = 'UPDATE' and new.assignee_membership_id is not distinct from old.assignee_membership_id then
    return new;
  end if;

  select profile_id into v_profil from public.club_memberships where id = new.assignee_membership_id;
  if v_profil is null then return new; end if;
  if v_profil = auth.uid() then return new; end if;
  if not public.meldung_erlaubt(v_profil, 'duty') then return new; end if;

  select display_name into v_wer from public.club_memberships
   where profile_id = auth.uid() and club_id = new.club_id limit 1;
  v_sprache := public.sprache_der_mitgliedschaft(new.assignee_membership_id);

  insert into public.user_notifications (profile_id, club_id, kind, title, body)
  values (v_profil, new.club_id, 'duty',
          public.meldungstext('aufgabe.zugewiesen.titel', v_sprache),
          public.meldungstext('aufgabe.zugewiesen.text', v_sprache,
            jsonb_build_object('wer', coalesce(v_wer, public.meldungstext('allg.vereinsleitung', v_sprache)))));
  return new;
end;
$function$;

create or replace function public.aufgaben_erinnerung_senden()
 returns integer language plpgsql security definer set search_path to ''
as $function$
declare v_anzahl integer := 0;
begin
  with faellig as (
    select t.id, t.club_id, t.title, m.profile_id, coalesce(pr.language, 'de') as sprache
    from public.duty_tasks t
    join public.club_memberships m on m.id = t.assignee_membership_id
    left join public.profiles pr on pr.id = m.profile_id
    where t.due_date = (current_date + 1)
      and t.reminded_at is null and t.done is not true
      and m.profile_id is not null
  ), gesendet as (
    insert into public.user_notifications (profile_id, club_id, kind, title, body)
    select f.profile_id, f.club_id, 'duty',
           public.meldungstext('erinnerung.titel', f.sprache),
           public.meldungstext('erinnerung.morgen', f.sprache, jsonb_build_object('titel', f.title))
    from faellig f
    where public.meldung_erlaubt(f.profile_id, 'duty')
    returning 1
  )
  update public.duty_tasks set reminded_at = now() where id in (select id from faellig);
  get diagnostics v_anzahl = row_count;

  with faellig2 as (
    select t.id, t.club_id, t.team_id, t.title,
           exists (select 1 from public.club_task_assignees a where a.task_id = t.id) as hat_verantwortliche
    from public.club_tasks t
    where t.due_date = (current_date + 1) and t.reminded_at is null
  ), empfaenger as (
    insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
    select distinct m.profile_id, f.club_id, 'tasks',
           public.meldungstext('erinnerung.titel', pr.language),
           public.meldungstext('erinnerung.morgen', pr.language, jsonb_build_object('titel', f.title)),
           'aufgabe', f.id
    from faellig2 f
    join public.club_memberships m on m.club_id = f.club_id and m.status = 'active'
    left join public.profiles pr on pr.id = m.profile_id
    left join public.team_members tm on tm.membership_id = m.id and tm.team_id = f.team_id
    left join public.club_task_assignees a on a.task_id = f.id and a.membership_id = m.id
    where m.profile_id is not null
      and (case when f.hat_verantwortliche then a.membership_id is not null
                when f.team_id is not null  then tm.membership_id is not null
                else true end)
      and public.team_meldung_erlaubt(m.id, f.team_id, 'aufgaben')
      and public.meldung_erlaubt(m.profile_id, 'tasks')
    returning 1
  )
  update public.club_tasks set reminded_at = now() where id in (select id from faellig2);

  return v_anzahl;
end;
$function$;

-- ------------------------------------------------------- Ergebnis-Erinnerung
create or replace function public.ergebnis_erinnerung_senden()
 returns integer language plpgsql security definer set search_path to 'public'
as $function$
declare v_anzahl integer := 0;
begin
  with faellig as (
    select e.id, e.club_id, e.title
    from public.events e
    left join public.event_results r on r.event_id = e.id
    where e.type = 'spiel'
      and e.status is distinct from 'cancelled'
      and e.starts_at < now() - interval '3 hours'
      and e.starts_at > now() - interval '7 days'
      and r.event_id is null
      and e.ergebnis_erinnert_at is null
  ), gesendet as (
    insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
    select distinct m.profile_id, f.club_id, 'results',
           public.meldungstext('ergebnis.fehlt.titel', p.language),
           public.meldungstext('ergebnis.fehlt.text', p.language, jsonb_build_object('titel', f.title)),
           'termin', f.id
    from faellig f
    join public.membership_roles ro on true
    join public.club_memberships m on m.id = ro.membership_id
    left join public.profiles p on p.id = m.profile_id
    where m.club_id = f.club_id and m.status = 'active' and m.profile_id is not null
      and ro.role in ('vereinsadmin','sysadmin','organisator')
      and public.meldung_erlaubt(m.profile_id, 'results')
    returning 1
  )
  update public.events set ergebnis_erinnert_at = now() where id in (select id from faellig);
  get diagnostics v_anzahl = row_count;
  return v_anzahl;
end;
$function$;

-- ----------------------------------------------------------- Vereinsfahrzeug
create or replace function public.fahrzeuganfrage_melden()
 returns trigger language plpgsql security definer set search_path to ''
as $function$
declare
  v_name text;
begin
  if new.status <> 'angefragt' then return new; end if;

  select display_name into v_name from public.club_memberships where id = new.membership_id;

  insert into public.user_notifications (profile_id, club_id, kind, title, body)
  select distinct m.profile_id, new.club_id, 'vehicle',
         public.meldungstext('fahrzeug.anfrage.titel', p.language),
         public.meldungstext('fahrzeug.anfrage.text', p.language,
           jsonb_build_object('wer', coalesce(v_name, public.meldungstext('allg.einMitglied', p.language))))
  from public.membership_roles r
  join public.club_memberships m on m.id = r.membership_id
  left join public.profiles p on p.id = m.profile_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and r.role in ('vereinsadmin', 'sysadmin', 'organisator')
    and public.meldung_erlaubt(m.profile_id, 'vehicle');

  return new;
end;
$function$;

create or replace function public.entscheide_fahrzeug_anfrage(target_booking uuid, annehmen boolean)
 returns text language plpgsql security definer set search_path to ''
as $function$
declare
  v_club uuid;
  v_anfrager uuid;
  v_profil uuid;
  v_status text;
  v_mein uuid;
  v_sprache text;
begin
  select club_id, membership_id, status into v_club, v_anfrager, v_status
  from public.vehicle_bookings where id = target_booking;
  if v_club is null then raise exception 'Booking not found'; end if;
  if not public.darf_fahrzeug_entscheiden(v_club) then raise exception 'Not authorized'; end if;
  if v_status <> 'angefragt' then return v_status; end if;

  select id into v_mein from public.club_memberships
   where club_id = v_club and profile_id = auth.uid() and status = 'active' limit 1;

  update public.vehicle_bookings
     set status = case when annehmen then 'bestaetigt' else 'abgelehnt' end,
         decided_by = v_mein, decided_at = now()
   where id = target_booking;

  select profile_id into v_profil from public.club_memberships where id = v_anfrager;
  if v_profil is not null and public.meldung_erlaubt(v_profil, 'vehicle') then
    v_sprache := public.sprache_der_mitgliedschaft(v_anfrager);
    insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
    values (v_profil, v_club, 'vehicle',
            public.meldungstext('fahrzeug.titel', v_sprache),
            public.meldungstext(case when annehmen then 'fahrzeug.angenommen' else 'fahrzeug.abgelehnt' end, v_sprache),
            'fahrzeug', target_booking);
  end if;

  return case when annehmen then 'bestaetigt' else 'abgelehnt' end;
end;
$function$;

-- ------------------------------------------------------------ Warteschlange
create or replace function public.warteschlange_in_glocke()
 returns trigger language plpgsql security definer set search_path to ''
as $function$
declare v_profil uuid; v_sprache text;
begin
  select profile_id into v_profil from public.club_memberships where id = new.membership_id;
  if v_profil is null then return new; end if;
  if not public.meldung_erlaubt(v_profil, coalesce(new.notif_type, 'info')) then return new; end if;

  /* Titel und Text kommen hier schon fertig uebersetzt an - notify_uebersetzt
     hat sie gesetzt, bevor die Zeile in die Warteschlange ging. Uebersetzt
     wird nur noch der Ersatztitel fuer den Fall, dass gar keiner mitkam. */
  v_sprache := public.sprache_der_mitgliedschaft(new.membership_id);

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  values (v_profil, new.club_id, coalesce(new.notif_type, 'info'),
          coalesce(new.title, public.meldungstext('allg.vereinsmeldung', v_sprache)),
          coalesce(new.body, ''),
          nullif(new.data ->> 'ziel_art', ''),
          case when (new.data ->> 'ziel_id') ~ '^[0-9a-fA-F-]{36}$'
               then (new.data ->> 'ziel_id')::uuid else null end);
  return new;
end;
$function$;

-- ============================================================================
-- Gruppe 2: Ausloeser, die ueber public.notify in die Warteschlange schreiben.
-- Sie rufen jetzt notify_uebersetzt und geben Schluessel statt fertiger Saetze.
-- ============================================================================

-- ------------------------------------------------------- Aufgabe angelegt
create or replace function public.aufgabe_melden()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_mitglied record;
begin
  for v_mitglied in
    select m.id
      from public.club_memberships m
     where m.club_id = new.club_id
       and m.status = 'active'
       and m.profile_id is not null
       and (new.team_id is null
            or exists (select 1 from public.team_members tm
                        where tm.membership_id = m.id and tm.team_id = new.team_id))
       and public.team_meldung_erlaubt(m.id, new.team_id, 'aufgaben')
  loop
    perform public.notify_uebersetzt(
      v_mitglied.id, 'tasks',
      'aufgabe.neu.titel',
      case when new.due_date is null then 'aufgabe.neu.textOhneDatum' else 'aufgabe.neu.text' end,
      jsonb_build_object('titel', new.title,
                         'datum', coalesce(to_char(new.due_date, 'DD.MM.YYYY'), '')),
      jsonb_build_object('ziel_art', 'aufgabe', 'ziel_id', new.id));
  end loop;
  return new;
end;
$$;

-- ------------------------------------------------------------- Beitritt
create or replace function public.beitritt_melden()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_verein  text;
  v_sprache text;
begin
  if tg_op <> 'UPDATE' or old.status <> 'pending' or new.status = 'pending' then
    return new;
  end if;
  if new.profile_id is null then return new; end if;

  select c.name into v_verein from public.clubs c where c.id = new.club_id;
  v_sprache := public.sprache_der_mitgliedschaft(new.id);

  if new.status = 'active' then
    perform public.notify_uebersetzt(new.id, 'join_requests',
      'beitritt.angenommen.titel', 'beitritt.angenommen.text',
      jsonb_build_object('verein', coalesce(v_verein, public.meldungstext('allg.deinVerein', v_sprache))));
  else
    perform public.notify_uebersetzt(new.id, 'join_requests',
      'beitritt.abgelehnt.titel', 'beitritt.abgelehnt.text',
      jsonb_build_object('verein', coalesce(v_verein, public.meldungstext('allg.deinVerein', v_sprache))));
  end if;
  return new;
end;
$$;

-- --------------------------------------------------------- Aufgabenschwelle
--
-- Wort fuer Wort die Fassung aus der Produktion - geaendert ist nur der
-- notify-Aufruf. Wichtig sind der Rueckgabewert boolean (die App wertet ihn
-- aus) und club_task_reminders: Der Aufruf kommt nach jeder Eintragung, die
-- Meldung darf aber nur ein einziges Mal je Verein hinausgehen.
create or replace function public.check_task_reminder_threshold(target_club uuid)
returns boolean language plpgsql security definer set search_path = 'public' as $$
declare
  total_active integer;
  signed_up integer;
  already_triggered boolean;
  member record;
begin
  select count(*) into total_active from public.club_memberships where club_id = target_club and status = 'active';
  if total_active = 0 then return false; end if;
  select count(distinct s.membership_id) into signed_up
  from public.club_task_signups s
  join public.club_memberships m on m.id = s.membership_id
  where m.club_id = target_club and m.status = 'active';
  select exists(select 1 from public.club_task_reminders where club_id = target_club) into already_triggered;
  if already_triggered then return false; end if;
  if (signed_up::numeric / total_active::numeric) >= 0.7 then
    insert into public.club_task_reminders (club_id) values (target_club) on conflict do nothing;
    for member in
      select m.id from public.club_memberships m
      where m.club_id = target_club and m.status = 'active'
        and m.id not in (select s.membership_id from public.club_task_signups s)
    loop
      perform public.notify_uebersetzt(member.id, 'tasks',
        'aufgaben.schwelle.titel', 'aufgaben.schwelle.text');
    end loop;
    return true;
  end if;
  return false;
end;
$$;

-- ------------------------------------------------------- Tippspiel/Ergebnis
create or replace function public.ergebnis_melden()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare
  v_event       record;
  v_vereinsname text;
  v_mannschaft  text;
  v_schluessel  text;
  v_empfaenger  record;
  v_tipper      record;
  v_sprache     text;
begin
  if tg_op = 'UPDATE'
     and new.heim is not distinct from old.heim
     and new.auswaerts is not distinct from old.auswaerts then
    return new;
  end if;

  select e.team_id, e.home_away, e.club_id, e.title
    into v_event
    from public.events e
   where e.id = new.event_id;
  if not found then return new; end if;

  select c.name into v_vereinsname from public.clubs c where c.id = new.club_id;
  select t.name into v_mannschaft from public.teams t where t.id = v_event.team_id;

  /* Wer getippt hat: Punkte stehen fest. Steht VOR dem Mannschafts-Block,
     denn der kehrt ohne Mannschaft frueh zurueck - ein Tippspiel gibt es auch
     fuer Begegnungen ohne hinterlegte Mannschaft. */
  for v_tipper in
    select m.id
      from public.predictions pr
      join public.club_memberships m
        on m.profile_id = pr.profile_id and m.club_id = new.club_id
     where pr.event_id = new.event_id and m.status = 'active'
  loop
    v_sprache := public.sprache_der_mitgliedschaft(v_tipper.id);
    perform public.notify_uebersetzt(v_tipper.id, 'tipp',
      'tipp.titel', 'tipp.text',
      jsonb_build_object(
        'titel', coalesce(v_event.title, public.meldungstext('allg.begegnung', v_sprache)),
        'heim', new.heim, 'auswaerts', new.auswaerts));
  end loop;

  if v_mannschaft is null then return new; end if;

  /* Sechs ganze Saetze statt "Das {spielart} der {mannschaft}": Im Deutschen
     laesst sich das zusammensetzen, in den romanischen Sprachen nicht -
     Artikel und Praeposition haengen am Wort. */
  v_schluessel := 'ergebnis.'
    || case when v_event.home_away = 'heim' then 'heim' else 'auswaerts' end
    || case when new.heim > new.auswaerts then '.gewonnen'
            when new.heim = new.auswaerts then '.unentschieden'
            else '.verloren' end;

  for v_empfaenger in
    select m.id
      from public.club_memberships m
     where m.club_id = new.club_id
       and m.status = 'active'
       and m.profile_id is not null
       and m.team_filter = v_mannschaft
  loop
    v_sprache := public.sprache_der_mitgliedschaft(v_empfaenger.id);
    perform public.notify(v_empfaenger.id, 'results'::text,
      public.meldungstext(v_schluessel, v_sprache, jsonb_build_object(
        'verein', coalesce(v_vereinsname, public.meldungstext('allg.verein', v_sprache)),
        'mannschaft', v_mannschaft,
        'heim', new.heim, 'auswaerts', new.auswaerts)),
      null::text);
  end loop;

  return new;
end;
$$;

-- ------------------------------------------------------- Fahrgemeinschaften
create or replace function public.notify_carpool_joined()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare
  driver_id uuid;
  passenger_name text;
  v_sprache text;
begin
  select driver_membership_id into driver_id from public.carpools where id = new.carpool_id;
  select display_name into passenger_name from public.club_memberships where id = new.membership_id;
  if driver_id is not null and driver_id <> new.membership_id then
    v_sprache := public.sprache_der_mitgliedschaft(driver_id);
    perform public.notify_uebersetzt(driver_id, 'carpool',
      'fahrgemeinschaft.neu.titel', 'fahrgemeinschaft.neu.text',
      jsonb_build_object('wer', coalesce(passenger_name, public.meldungstext('allg.jemand', v_sprache))),
      jsonb_build_object('carpool_id', new.carpool_id));
  end if;
  return new;
end;
$$;

create or replace function public.run_carpool_gap_check()
returns void language plpgsql security definer set search_path = 'public' as $$
declare
  ev record;
  member record;
begin
  for ev in
    select e.id, e.club_id, e.team_id, e.title, e.starts_at
    from public.events e
    where e.status = 'scheduled' and coalesce(e.home_away, 'auswaerts') <> 'heim'
      and e.starts_at::date = current_date + interval '3 days'
      and e.team_id is not null
      and not exists (select 1 from public.carpools c where c.event_id = e.id)
  loop
    for member in select distinct membership_id as id from public.team_members where team_id = ev.team_id loop
      perform public.notify_uebersetzt(member.id, 'carpool',
        'fahrgemeinschaft.fehlt.titel', 'fahrgemeinschaft.fehlt.text',
        jsonb_build_object('titel', ev.title, 'datum', to_char(ev.starts_at, 'DD.MM.')),
        jsonb_build_object('event_id', ev.id));
    end loop;
  end loop;
end;
$$;

-- ------------------------------------------------------------- Familie
create or replace function public.notify_family_link_created()
returns trigger language plpgsql security definer set search_path = 'public' as $$
begin
  perform public.notify_uebersetzt(new.first_membership_id,  'family', 'familie.titel', 'familie.text');
  perform public.notify_uebersetzt(new.second_membership_id, 'family', 'familie.titel', 'familie.text');
  return new;
end;
$$;

-- -------------------------------------------------------------- Strafen
--
-- Fehlt der Name der Strafe, wird NICHT ein Wort in den Satz gesetzt, sondern
-- ein anderer Satz genommen. Sonst entsteht auf Franzoesisch
-- "Tu as reçu une sanction : Une sanction."
--
-- Die Waechter bleiben unveraendert: paid meldet nur beim UEBERGANG auf
-- bezahlt, removed nur bei einer echten Loeschung - nicht, wenn eine Strafe
-- am Saisonende ins Archiv wandert.
create or replace function public.notify_penalty_assigned()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare rule_title text;
begin
  select title into rule_title from public.team_penalty_rules where id = new.rule_id;
  perform public.notify_uebersetzt(new.membership_id, 'penalties',
    'strafe.neu.titel',
    case when rule_title is null then 'strafe.neu.textOhneRegel' else 'strafe.neu.text' end,
    jsonb_build_object('regel', coalesce(rule_title, '')),
    jsonb_build_object('assignment_id', new.id));
  return new;
end;
$$;

create or replace function public.notify_penalty_paid()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare rule_title text;
begin
  if old.paid_at is null and new.paid_at is not null then
    select title into rule_title from public.team_penalty_rules where id = new.rule_id;
    perform public.notify_uebersetzt(new.membership_id, 'penalties',
      'strafe.bezahlt.titel',
      case when rule_title is null then 'strafe.bezahlt.textOhneRegel' else 'strafe.bezahlt.text' end,
      jsonb_build_object('regel', coalesce(rule_title, '')),
      jsonb_build_object('assignment_id', new.id));
  end if;
  return new;
end;
$$;

create or replace function public.notify_penalty_removed()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare rule_title text;
begin
  if old.archived_season is null then
    select title into rule_title from public.team_penalty_rules where id = old.rule_id;
    perform public.notify_uebersetzt(old.membership_id, 'penalties',
      'strafe.zurueck.titel',
      case when rule_title is null then 'strafe.zurueck.textOhneRegel' else 'strafe.zurueck.text' end,
      jsonb_build_object('regel', coalesce(rule_title, '')));
  end if;
  return old;
end;
$$;

-- --------------------------------------------------------- Mannschaft, Rest
create or replace function public.notify_team_joined()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare team_name text;
begin
  select name into team_name from public.teams where id = new.team_id;
  perform public.notify_uebersetzt(new.membership_id, 'membership',
    'team.willkommen.titel', 'team.willkommen.text',
    jsonb_build_object('team', coalesce(team_name, '')));
  return new;
end;
$$;

/* Wer selbst storniert, braucht keine Meldung darueber. */
create or replace function public.notify_vehicle_booking_cancelled()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare
  acting_profile uuid;
begin
  select profile_id into acting_profile from public.club_memberships where id = old.membership_id;
  if acting_profile is distinct from auth.uid() then
    perform public.notify_uebersetzt(old.membership_id, 'carpool',
      'fahrzeug.storniert.titel', 'fahrzeug.storniert.text');
  end if;
  return old;
end;
$$;

/* Das Geburtstagskind bekommt keine Meldung ueber sich selbst - daher
   id <> bday.membership_id. */
create or replace function public.run_birthday_reminders()
returns void language plpgsql security definer set search_path = 'public' as $$
declare
  bday record;
  member record;
begin
  for bday in
    select m.id as membership_id, m.club_id, m.display_name
    from public.club_memberships m
    join public.profiles p on p.id = m.profile_id
    where m.status = 'active' and p.show_birthday = true
      and extract(month from p.birthdate) = extract(month from current_date)
      and extract(day from p.birthdate) = extract(day from current_date)
  loop
    for member in
      select id from public.club_memberships
      where club_id = bday.club_id and status = 'active' and id <> bday.membership_id
    loop
      perform public.notify_uebersetzt(member.id, 'birthdays',
        'geburtstag.titel', 'geburtstag.text',
        jsonb_build_object('wer', bday.display_name));
    end loop;
  end loop;
end;
$$;

create or replace function public.run_duty_gap_check()
returns void language plpgsql security definer set search_path = 'public' as $$
declare
  ev record;
  member record;
begin
  for ev in
    select e.id, e.club_id, e.team_id, e.title, e.starts_at
    from public.events e
    where e.status = 'scheduled' and e.home_away = 'heim'
      and e.starts_at::date = current_date + interval '3 days'
      and exists (select 1 from public.duty_tasks dt where dt.event_id = e.id and dt.assignee_membership_id is null and dt.done = false)
  loop
    for member in select distinct membership_id as id from public.team_members where team_id = ev.team_id loop
      perform public.notify_uebersetzt(member.id, 'duty',
        'helfer.gesucht.titel', 'helfer.gesucht.text',
        jsonb_build_object('titel', ev.title, 'datum', to_char(ev.starts_at, 'DD.MM.')),
        jsonb_build_object('event_id', ev.id));
    end loop;
  end loop;
end;
$$;

/* reminded_at ist die Sperre gegen taegliche Wiederholung. Ohne sie erinnert
   der naechtliche Auftrag jeden Tag aufs Neue an dieselbe Aufgabe. */
create or replace function public.run_duty_task_due_reminders()
returns void language plpgsql security definer set search_path = 'public' as $$
declare
  t record;
begin
  for t in
    select id, assignee_membership_id, title from public.duty_tasks
    where due_date = current_date + 1 and assignee_membership_id is not null and not done and reminded_at is null
  loop
    perform public.notify_uebersetzt(t.assignee_membership_id, 'duty',
      'helfer.faellig.titel', 'helfer.faellig.text',
      jsonb_build_object('titel', t.title));
    update public.duty_tasks set reminded_at = now() where id = t.id;
  end loop;
end;
$$;

create or replace function public.sponsor_melden()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare v_mitglied record;
begin
  if new.active is not true then return new; end if;

  for v_mitglied in
    select m.id from public.club_memberships m
     where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
  loop
    /* Der Sponsorenname ist ein Eigenname und bleibt, wie er ist - nur die
       Ueberschrift wird uebersetzt. */
    perform public.notify(v_mitglied.id, 'news'::text,
      public.meldungstext('sponsor.titel', public.sprache_der_mitgliedschaft(v_mitglied.id)),
      new.name::text);
  end loop;
  return new;
end;
$$;

-- ---------------------------------------------------------------- Nachweis
select
  (select count(distinct schluessel) from public.meldungstexte) as bausteine,
  (select count(*) from public.meldungstexte) as zeilen,
  (select count(*) from (select schluessel from public.meldungstexte
                          group by schluessel having count(*) <> 7) x) as unvollstaendig,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosrc ~ '(Aufgabe wurde|Training wurde|Spiel wurde|Willkommen bei|hat heute Geburtstag|werden noch Helfer)') as deutsch_uebrig;

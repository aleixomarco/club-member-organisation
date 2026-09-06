/* Sprachen der App.
 *
 * WARUM EINE EIGENE DATEI
 * page.tsx hat rund 11.000 Zeilen. Die Texte dort hineinzuschreiben haette sie
 * um Tausende weitere verlaengert - und beim Uebersetzen muesste man jedes Mal
 * durch die ganze App scrollen. Hier stehen sie beieinander und lassen sich
 * Sprache fuer Sprache vervollstaendigen.
 *
 * WIE DIE UEBERSETZUNG FEHLSCHLAEGT
 * Fehlt ein Schluessel in einer Sprache, faellt t() auf Deutsch zurueck - nicht
 * auf den Schluessel selbst. Ein Nutzer sieht dann einen deutschen Satz, was
 * unschoen ist; er saehe sonst "profil.titel", was unbrauchbar ist.
 *
 * STAND
 * Uebersetzt sind die Bildschirme, die ein neuer Nutzer zuerst sieht:
 * Sprachwahl, Anmeldung, Registrierung. Der Rest der App bleibt vorerst
 * deutsch - die Umstellung erfolgt in Schritten, damit nicht die halbe App
 * zwischen zwei Sprachen steht.
 */

export const SPRACHEN = [
  { code: "de", name: "Deutsch",    flagge: "🇩🇪" },
  { code: "en", name: "English",    flagge: "🇬🇧" },
  { code: "es", name: "Español",    flagge: "🇪🇸" },
  { code: "pt", name: "Português",  flagge: "🇵🇹" },
  { code: "it", name: "Italiano",   flagge: "🇮🇹" },
  { code: "tr", name: "Türkçe",     flagge: "🇹🇷" },
  { code: "fr", name: "Français",   flagge: "🇫🇷" },
] as const;

export type Sprachcode = (typeof SPRACHEN)[number]["code"];

type Woerterbuch = Record<string, string>;

const de: Woerterbuch = {
  "nav.home": "Home",
  "nav.events": "Termine",
  "nav.teams": "Teams",
  "nav.chat": "Chat",
  "nav.profile": "Profil",
  "nav.fees": "Beiträge",
  "nav.news": "Redaktion",
  "nav.admin": "Verwaltung",
  "nav.sponsors": "Sponsoren",
  "sub.season": "Athlet/in der Saison",
  "sub.tipp": "Tippspiel",
  "sub.duty": "Helferplanung",
  "sub.postfach": "Benachrichtigungen",
  "sprache.titel": "Sprache wählen",
  "sprache.hinweis": "In welcher Sprache möchtest du die App nutzen? Du kannst das später im Profil ändern.",
  "sprache.weiter": "Weiter",

  "login.willkommen": "Willkommen zurück",
  "login.email": "E-Mail-Adresse",
  "login.passwort": "Passwort",
  "login.vergessen": "Passwort vergessen?",
  "login.anmelden": "Anmelden",
  "login.keinKonto": "Noch kein Konto?",
  "login.registrieren": "Jetzt registrieren",

  "reg.titel": "Konto erstellen",
  "reg.vorname": "Vorname",
  "reg.nachname": "Nachname",
  "reg.schonMitglied": "Schon Mitglied?",
  "reg.anmelden": "Anmelden",
  "reg.fastGeschafft": "Fast geschafft",
  "reg.bestaetigen": "Du erhältst eine E-Mail. Bitte bestätige sie, damit wir sicher gehen können, dass deine Daten korrekt sind.",
  "reg.danach": "Anschließend kannst du dich anmelden.",
  "reg.jetztAnmelden": "Jetzt anmelden",
  "reg.keineMail": "Keine E-Mail erhalten? Sieh im Spam-Ordner nach — sie kommt meist innerhalb einer Minute.",

  "profil.sprache": "Sprache",
  "profil.spracheHinweis": "Sprache der App",
};

const en: Woerterbuch = {
  "nav.home": "Home",
  "nav.events": "Schedule",
  "nav.teams": "Teams",
  "nav.chat": "Chat",
  "nav.profile": "Profile",
  "nav.fees": "Fees",
  "nav.news": "News desk",
  "nav.admin": "Admin",
  "nav.sponsors": "Sponsors",
  "sub.season": "Athlete of the season",
  "sub.tipp": "Prediction game",
  "sub.duty": "Volunteer roster",
  "sub.postfach": "Notifications",
  "sprache.titel": "Choose your language",
  "sprache.hinweis": "Which language would you like to use? You can change this later in your profile.",
  "sprache.weiter": "Continue",
  "login.willkommen": "Welcome back",
  "login.email": "Email address",
  "login.passwort": "Password",
  "login.vergessen": "Forgot your password?",
  "login.anmelden": "Sign in",
  "login.keinKonto": "No account yet?",
  "login.registrieren": "Sign up",
  "reg.titel": "Create account",
  "reg.vorname": "First name",
  "reg.nachname": "Last name",
  "reg.schonMitglied": "Already a member?",
  "reg.anmelden": "Sign in",
  "reg.fastGeschafft": "Almost done",
  "reg.bestaetigen": "You will receive an email. Please confirm it so we can be sure your details are correct.",
  "reg.danach": "After that you can sign in.",
  "reg.jetztAnmelden": "Sign in now",
  "reg.keineMail": "No email? Check your spam folder — it usually arrives within a minute.",
  "profil.sprache": "Language",
  "profil.spracheHinweis": "App language",
};

const es: Woerterbuch = {
  "nav.home": "Inicio",
  "nav.events": "Agenda",
  "nav.teams": "Equipos",
  "nav.chat": "Chat",
  "nav.profile": "Perfil",
  "nav.fees": "Cuotas",
  "nav.news": "Redacción",
  "nav.admin": "Administración",
  "nav.sponsors": "Patrocinadores",
  "sub.season": "Atleta de la temporada",
  "sub.tipp": "Quiniela",
  "sub.duty": "Turnos de voluntarios",
  "sub.postfach": "Notificaciones",
  "sprache.titel": "Elige tu idioma",
  "sprache.hinweis": "¿En qué idioma quieres usar la aplicación? Puedes cambiarlo más tarde en tu perfil.",
  "sprache.weiter": "Continuar",
  "login.willkommen": "Bienvenido de nuevo",
  "login.email": "Correo electrónico",
  "login.passwort": "Contraseña",
  "login.vergessen": "¿Olvidaste tu contraseña?",
  "login.anmelden": "Iniciar sesión",
  "login.keinKonto": "¿Aún no tienes cuenta?",
  "login.registrieren": "Regístrate",
  "reg.titel": "Crear cuenta",
  "reg.vorname": "Nombre",
  "reg.nachname": "Apellido",
  "reg.schonMitglied": "¿Ya eres miembro?",
  "reg.anmelden": "Iniciar sesión",
  "reg.fastGeschafft": "Casi listo",
  "reg.bestaetigen": "Recibirás un correo electrónico. Confírmalo para que podamos asegurarnos de que tus datos son correctos.",
  "reg.danach": "Después podrás iniciar sesión.",
  "reg.jetztAnmelden": "Iniciar sesión",
  "reg.keineMail": "¿No recibiste el correo? Revisa la carpeta de spam — suele llegar en un minuto.",
  "profil.sprache": "Idioma",
  "profil.spracheHinweis": "Idioma de la aplicación",
};

const pt: Woerterbuch = {
  "nav.home": "Início",
  "nav.events": "Agenda",
  "nav.teams": "Equipas",
  "nav.chat": "Chat",
  "nav.profile": "Perfil",
  "nav.fees": "Quotas",
  "nav.news": "Redação",
  "nav.admin": "Administração",
  "nav.sponsors": "Patrocinadores",
  "sub.season": "Atleta da época",
  "sub.tipp": "Bolão",
  "sub.duty": "Escala de voluntários",
  "sub.postfach": "Notificações",
  "sprache.titel": "Escolhe o teu idioma",
  "sprache.hinweis": "Em que idioma queres usar a aplicação? Podes alterar mais tarde no teu perfil.",
  "sprache.weiter": "Continuar",
  "login.willkommen": "Bem-vindo de volta",
  "login.email": "Endereço de e-mail",
  "login.passwort": "Palavra-passe",
  "login.vergessen": "Esqueceste a palavra-passe?",
  "login.anmelden": "Entrar",
  "login.keinKonto": "Ainda não tens conta?",
  "login.registrieren": "Registar",
  "reg.titel": "Criar conta",
  "reg.vorname": "Nome próprio",
  "reg.nachname": "Apelido",
  "reg.schonMitglied": "Já és membro?",
  "reg.anmelden": "Entrar",
  "reg.fastGeschafft": "Quase pronto",
  "reg.bestaetigen": "Vais receber um e-mail. Confirma-o para termos a certeza de que os teus dados estão corretos.",
  "reg.danach": "Depois disso podes entrar.",
  "reg.jetztAnmelden": "Entrar agora",
  "reg.keineMail": "Não recebeste o e-mail? Vê a pasta de spam — costuma chegar num minuto.",
  "profil.sprache": "Idioma",
  "profil.spracheHinweis": "Idioma da aplicação",
};

const it: Woerterbuch = {
  "nav.home": "Home",
  "nav.events": "Calendario",
  "nav.teams": "Squadre",
  "nav.chat": "Chat",
  "nav.profile": "Profilo",
  "nav.fees": "Quote",
  "nav.news": "Redazione",
  "nav.admin": "Amministrazione",
  "nav.sponsors": "Sponsor",
  "sub.season": "Atleta della stagione",
  "sub.tipp": "Pronostici",
  "sub.duty": "Turni volontari",
  "sub.postfach": "Notifiche",
  "sprache.titel": "Scegli la lingua",
  "sprache.hinweis": "In quale lingua vuoi usare l'app? Puoi cambiarla più tardi nel profilo.",
  "sprache.weiter": "Avanti",
  "login.willkommen": "Bentornato",
  "login.email": "Indirizzo e-mail",
  "login.passwort": "Password",
  "login.vergessen": "Password dimenticata?",
  "login.anmelden": "Accedi",
  "login.keinKonto": "Non hai ancora un account?",
  "login.registrieren": "Registrati",
  "reg.titel": "Crea account",
  "reg.vorname": "Nome",
  "reg.nachname": "Cognome",
  "reg.schonMitglied": "Sei già membro?",
  "reg.anmelden": "Accedi",
  "reg.fastGeschafft": "Ci siamo quasi",
  "reg.bestaetigen": "Riceverai un'e-mail. Confermala così possiamo essere certi che i tuoi dati siano corretti.",
  "reg.danach": "Dopodiché potrai accedere.",
  "reg.jetztAnmelden": "Accedi ora",
  "reg.keineMail": "Nessuna e-mail? Controlla la cartella spam — di solito arriva entro un minuto.",
  "profil.sprache": "Lingua",
  "profil.spracheHinweis": "Lingua dell'app",
};

const tr: Woerterbuch = {
  "nav.home": "Ana sayfa",
  "nav.events": "Takvim",
  "nav.teams": "Takımlar",
  "nav.chat": "Sohbet",
  "nav.profile": "Profil",
  "nav.fees": "Aidatlar",
  "nav.news": "Haberler",
  "nav.admin": "Yönetim",
  "nav.sponsors": "Sponsorlar",
  "sub.season": "Sezonun sporcusu",
  "sub.tipp": "Tahmin oyunu",
  "sub.duty": "Gönüllü görevleri",
  "sub.postfach": "Bildirimler",
  "sprache.titel": "Dilini seç",
  "sprache.hinweis": "Uygulamayı hangi dilde kullanmak istersin? Bunu daha sonra profilinden değiştirebilirsin.",
  "sprache.weiter": "Devam",
  "login.willkommen": "Tekrar hoş geldin",
  "login.email": "E-posta adresi",
  "login.passwort": "Şifre",
  "login.vergessen": "Şifreni mi unuttun?",
  "login.anmelden": "Giriş yap",
  "login.keinKonto": "Hesabın yok mu?",
  "login.registrieren": "Kayıt ol",
  "reg.titel": "Hesap oluştur",
  "reg.vorname": "Ad",
  "reg.nachname": "Soyad",
  "reg.schonMitglied": "Zaten üye misin?",
  "reg.anmelden": "Giriş yap",
  "reg.fastGeschafft": "Neredeyse tamam",
  "reg.bestaetigen": "Bir e-posta alacaksın. Bilgilerinin doğru olduğundan emin olabilmemiz için lütfen onayla.",
  "reg.danach": "Ardından giriş yapabilirsin.",
  "reg.jetztAnmelden": "Şimdi giriş yap",
  "reg.keineMail": "E-posta gelmedi mi? Spam klasörüne bak — genellikle bir dakika içinde gelir.",
  "profil.sprache": "Dil",
  "profil.spracheHinweis": "Uygulama dili",
};

const fr: Woerterbuch = {
  "nav.home": "Accueil",
  "nav.events": "Agenda",
  "nav.teams": "Équipes",
  "nav.chat": "Chat",
  "nav.profile": "Profil",
  "nav.fees": "Cotisations",
  "nav.news": "Rédaction",
  "nav.admin": "Administration",
  "nav.sponsors": "Sponsors",
  "sub.season": "Athlète de la saison",
  "sub.tipp": "Pronostics",
  "sub.duty": "Bénévoles",
  "sub.postfach": "Notifications",
  "sprache.titel": "Choisis ta langue",
  "sprache.hinweis": "Dans quelle langue veux-tu utiliser l'application ? Tu pourras la changer plus tard dans ton profil.",
  "sprache.weiter": "Continuer",
  "login.willkommen": "Bon retour",
  "login.email": "Adresse e-mail",
  "login.passwort": "Mot de passe",
  "login.vergessen": "Mot de passe oublié ?",
  "login.anmelden": "Se connecter",
  "login.keinKonto": "Pas encore de compte ?",
  "login.registrieren": "S'inscrire",
  "reg.titel": "Créer un compte",
  "reg.vorname": "Prénom",
  "reg.nachname": "Nom",
  "reg.schonMitglied": "Déjà membre ?",
  "reg.anmelden": "Se connecter",
  "reg.fastGeschafft": "Presque terminé",
  "reg.bestaetigen": "Tu vas recevoir un e-mail. Merci de le confirmer pour que nous soyons sûrs que tes données sont correctes.",
  "reg.danach": "Ensuite, tu pourras te connecter.",
  "reg.jetztAnmelden": "Se connecter",
  "reg.keineMail": "Pas d'e-mail ? Regarde dans les indésirables — il arrive généralement en une minute.",
  "profil.sprache": "Langue",
  "profil.spracheHinweis": "Langue de l'application",
};

const WOERTERBUECHER: Record<string, Woerterbuch> = { de, en, es, pt, it, tr, fr };

export const SPRACHE_SPEICHER = "cmo.sprache";

/* Die gewaehlte Sprache aus dem Geraet lesen.
   Sie steht dort UND am Konto: Im Geraet, weil die Wahl vor der Anmeldung
   getroffen wird und es dann noch kein Konto gibt; am Konto, damit sie auf
   einem zweiten Geraet nicht erneut abgefragt wird. */
export function gespeicherteSprache(): Sprachcode | null {
  if (typeof window === "undefined") return null;
  try {
    const wert = window.localStorage.getItem(SPRACHE_SPEICHER);
    return SPRACHEN.some((s) => s.code === wert) ? (wert as Sprachcode) : null;
  } catch {
    /* Privater Modus, gesperrte Website-Daten: Dann wird eben jedes Mal
       gefragt - besser als ein Absturz beim Start. */
    return null;
  }
}

export function spracheMerken(code: string) {
  if (typeof window === "undefined") return;
  try { window.localStorage.setItem(SPRACHE_SPEICHER, code); } catch { /* siehe oben */ }
}

/* Uebersetzen. Fehlt ein Schluessel, kommt der deutsche Text - nicht der
   Schluessel. Ein deutscher Satz ist unschoen, "profil.titel" ist unbrauchbar. */
export function uebersetze(code: string, schluessel: string): string {
  return WOERTERBUECHER[code]?.[schluessel] ?? de[schluessel] ?? schluessel;
}

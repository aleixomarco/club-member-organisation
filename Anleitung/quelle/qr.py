# -*- coding: utf-8 -*-
"""Ein QR-Code als SVG - ohne Fremdpaket und ohne Fremddienst.

Absichtlich auf EINE Fassung festgelegt: Version 5, Fehlerkorrektur M
(37 x 37 Felder, 84 Zeichen im Byte-Modus). Beide Adressen passen hinein
(42 und 67 Zeichen), und eine einzige Tabellenzeile ist weniger, was falsch
sein kann, als eine allgemeine Fassungswahl.

Fehlerkorrektur M haelt rund 15 Prozent Beschaedigung aus - genug fuer ein
gedrucktes Blatt, das in einer Sporttasche steckt.
"""

VERSION = 5
GROESSE = 37                 # 4 * 5 + 17
DATEN_WOERTER = 86           # gesamt
BLOECKE = 2
JE_BLOCK = 43
EC_JE_BLOCK = 24
AUSRICHTUNG = [6, 30]        # Mittelpunkte der Ausrichtungsmuster

# ---- Galois-Feld 256, Generator 0x11D ----
LOG = [0] * 256
EXP = [0] * 512
x = 1
for i in range(255):
    EXP[i] = x
    LOG[x] = i
    x <<= 1
    if x & 0x100:
        x ^= 0x11D
for i in range(255, 512):
    EXP[i] = EXP[i - 255]

def mal(a, b):
    if a == 0 or b == 0:
        return 0
    return EXP[LOG[a] + LOG[b]]

def generator(grad):
    g = [1]
    for i in range(grad):
        neu = [0] * (len(g) + 1)
        for j, wert in enumerate(g):
            neu[j] ^= mal(wert, 1)
            neu[j + 1] ^= mal(wert, EXP[i])
        g = neu
    return g

def fehlerkorrektur(daten, anzahl):
    g = generator(anzahl)
    rest = list(daten) + [0] * anzahl
    for i in range(len(daten)):
        f = rest[i]
        if f:
            for j, gw in enumerate(g):
                rest[i + j] ^= mal(gw, f)
    return rest[len(daten):]

# ---- Datenstrom ----
def bitstrom(text):
    roh = text.encode("utf-8")
    if len(roh) > 84:
        raise ValueError(f"{len(roh)} Bytes passen nicht in Version 5-M (84)")
    bits = []
    def schreibe(wert, breite):
        for i in range(breite - 1, -1, -1):
            bits.append((wert >> i) & 1)
    schreibe(0b0100, 4)          # Byte-Modus
    schreibe(len(roh), 8)        # Laengenangabe, 8 Bit bei Version 1-9
    for b in roh:
        schreibe(b, 8)
    # Abschluss, hoechstens vier Nullen
    for _ in range(min(4, DATEN_WOERTER * 8 - len(bits))):
        bits.append(0)
    while len(bits) % 8:
        bits.append(0)
    woerter = [int("".join(map(str, bits[i:i + 8])), 2) for i in range(0, len(bits), 8)]
    fueller = [0xEC, 0x11]
    i = 0
    while len(woerter) < DATEN_WOERTER:
        woerter.append(fueller[i % 2])
        i += 1
    return woerter

def endgueltige_woerter(text):
    daten = bitstrom(text)
    bloecke = [daten[i * JE_BLOCK:(i + 1) * JE_BLOCK] for i in range(BLOECKE)]
    ecs = [fehlerkorrektur(b, EC_JE_BLOCK) for b in bloecke]
    aus = []
    for i in range(JE_BLOCK):
        for b in bloecke:
            aus.append(b[i])
    for i in range(EC_JE_BLOCK):
        for ec in ecs:
            aus.append(ec[i])
    return aus

# ---- Matrix ----
def leere_matrix():
    return [[None] * GROESSE for _ in range(GROESSE)]

def suchmuster(m, zeile, spalte):
    for r in range(-1, 8):
        for c in range(-1, 8):
            zr, zc = zeile + r, spalte + c
            if not (0 <= zr < GROESSE and 0 <= zc < GROESSE):
                continue
            rand = (0 <= r <= 6 and c in (0, 6)) or (0 <= c <= 6 and r in (0, 6))
            kern = 2 <= r <= 4 and 2 <= c <= 4
            m[zr][zc] = 1 if (rand or kern) else 0

def ausrichtungsmuster(m, zeile, spalte):
    for r in range(-2, 3):
        for c in range(-2, 3):
            m[zeile + r][spalte + c] = 0 if (abs(r) == 1 or abs(c) == 1) else 1

def grundmuster():
    m = leere_matrix()
    suchmuster(m, 0, 0); suchmuster(m, 0, GROESSE - 7); suchmuster(m, GROESSE - 7, 0)
    for i in range(8, GROESSE - 8):
        m[6][i] = 1 - (i % 2)
        m[i][6] = 1 - (i % 2)
    for zr in AUSRICHTUNG:
        for zc in AUSRICHTUNG:
            if m[zr][zc] is None:
                ausrichtungsmuster(m, zr, zc)
    m[4 * VERSION + 9][8] = 1          # das immer dunkle Feld
    # Plaetze fuer die Formatangabe freihalten
    for i in range(9):
        if m[8][i] is None: m[8][i] = 0
        if m[i][8] is None: m[i][8] = 0
    for i in range(8):
        if m[8][GROESSE - 1 - i] is None: m[8][GROESSE - 1 - i] = 0
        if m[GROESSE - 1 - i][8] is None: m[GROESSE - 1 - i][8] = 0
    return m

def belegt(grund):
    return [[grund[r][c] is not None for c in range(GROESSE)] for r in range(GROESSE)]

def daten_setzen(m, fest, woerter):
    bits = []
    for w in woerter:
        for i in range(7, -1, -1):
            bits.append((w >> i) & 1)
    idx = 0
    spalte = GROESSE - 1
    aufwaerts = True
    while spalte > 0:
        if spalte == 6:
            spalte -= 1
        zeilen = range(GROESSE - 1, -1, -1) if aufwaerts else range(GROESSE)
        for zeile in zeilen:
            for versatz in (0, 1):
                c = spalte - versatz
                if fest[zeile][c]:
                    continue
                m[zeile][c] = bits[idx] if idx < len(bits) else 0
                idx += 1
        spalte -= 2
        aufwaerts = not aufwaerts

MASKEN = [
    lambda r, c: (r + c) % 2 == 0,
    lambda r, c: r % 2 == 0,
    lambda r, c: c % 3 == 0,
    lambda r, c: (r + c) % 3 == 0,
    lambda r, c: (r // 2 + c // 3) % 2 == 0,
    lambda r, c: (r * c) % 2 + (r * c) % 3 == 0,
    lambda r, c: ((r * c) % 2 + (r * c) % 3) % 2 == 0,
    lambda r, c: ((r + c) % 2 + (r * c) % 3) % 2 == 0,
]

def strafe(m):
    p = 0
    # Regel 1: Reihen gleicher Farbe
    for linien in (m, list(map(list, zip(*m)))):
        for zeile in linien:
            lauf, vor = 1, zeile[0]
            for wert in zeile[1:]:
                if wert == vor:
                    lauf += 1
                else:
                    if lauf >= 5: p += 3 + (lauf - 5)
                    lauf, vor = 1, wert
            if lauf >= 5: p += 3 + (lauf - 5)
    # Regel 2: gleichfarbige Bloecke 2x2
    for r in range(GROESSE - 1):
        for c in range(GROESSE - 1):
            if m[r][c] == m[r][c+1] == m[r+1][c] == m[r+1][c+1]:
                p += 3
    # Regel 3: suchmusteraehnliche Folgen
    folge = [1,0,1,1,1,0,1,0,0,0,0]
    for linien in (m, list(map(list, zip(*m)))):
        for zeile in linien:
            for i in range(GROESSE - 10):
                stueck = list(zeile[i:i+11])
                if stueck == folge or stueck == folge[::-1]:
                    p += 40
    # Regel 4: Verhaeltnis dunkel zu hell
    dunkel = sum(sum(z) for z in m)
    anteil = dunkel * 100 // (GROESSE * GROESSE)
    p += 10 * (min(abs(anteil - 50) // 5, 10))
    return p

def formatangabe(m, maske):
    # Fehlerkorrektur M = 00
    wert = (0b00 << 3) | maske
    rest = wert << 10
    for i in range(4, -1, -1):
        if rest & (1 << (i + 10)):
            rest ^= 0b10100110111 << i
    bits = ((wert << 10) | rest) ^ 0b101010000010010
    # Die Plaetze unten sind von der hoechstwertigen Stelle her aufgezaehlt.
    # Andersherum liest kein Geraet den Code: Beim ersten Versuch stand die
    # Formatangabe spiegelverkehrt, und der Leser von macOS erkannte gar
    # nichts. Geprueft ist die Reihenfolge nicht durch Nachdenken, sondern
    # durch Gegenlesen - alle vier moeglichen Konventionen durchprobiert.
    folge = [(bits >> i) & 1 for i in range(14, -1, -1)]
    # links oben
    plaetze1 = [(8,0),(8,1),(8,2),(8,3),(8,4),(8,5),(8,7),(8,8),(7,8),(5,8),(4,8),(3,8),(2,8),(1,8),(0,8)]
    for bit, (r, c) in zip(folge, plaetze1):
        m[r][c] = bit
    # rechts oben und links unten
    plaetze2 = [(GROESSE-1,8),(GROESSE-2,8),(GROESSE-3,8),(GROESSE-4,8),(GROESSE-5,8),(GROESSE-6,8),(GROESSE-7,8),
                (8,GROESSE-8),(8,GROESSE-7),(8,GROESSE-6),(8,GROESSE-5),(8,GROESSE-4),(8,GROESSE-3),(8,GROESSE-2),(8,GROESSE-1)]
    for bit, (r, c) in zip(folge, plaetze2):
        m[r][c] = bit

def bauen(text):
    grund = grundmuster()
    fest = belegt(grund)
    woerter = endgueltige_woerter(text)
    beste, bestwert = None, None
    for maske in range(8):
        m = [zeile[:] for zeile in grund]
        daten_setzen(m, fest, woerter)
        for r in range(GROESSE):
            for c in range(GROESSE):
                if not fest[r][c] and MASKEN[maske](r, c):
                    m[r][c] ^= 1
        formatangabe(m, maske)
        wert = strafe(m)
        if bestwert is None or wert < bestwert:
            beste, bestwert = m, wert
    return beste

def als_svg(text, kantenlaenge_mm=26, rand=4):
    m = bauen(text)
    n = GROESSE + 2 * rand
    teile = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {n} {n}" '
             f'width="{kantenlaenge_mm}mm" height="{kantenlaenge_mm}mm" shape-rendering="crispEdges">',
             f'<rect width="{n}" height="{n}" fill="#FFFFFF"/>']
    for r in range(GROESSE):
        for c in range(GROESSE):
            if m[r][c]:
                teile.append(f'<rect x="{c+rand}" y="{r+rand}" width="1" height="1" fill="#14151A"/>')
    teile.append("</svg>")
    return "".join(teile)

if __name__ == "__main__":
    import sys, io as _io
    ziel, datei = sys.argv[1], sys.argv[2]
    _io.open(datei, "w", encoding="utf-8").write(als_svg(ziel))
    print(f"  {datei}  <-  {ziel}")

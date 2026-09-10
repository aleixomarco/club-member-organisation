# -*- coding: utf-8 -*-
"""Den QR-Code zusaetzlich als PNG - nur zum Gegenlesen, nicht fuer das PDF."""
import sys, zlib, struct, io
sys.path.insert(0, sys.path[0] or ".")
from qr import bauen, GROESSE

def png(text, datei, feld=12, rand=4):
    m = bauen(text)
    n = (GROESSE + 2 * rand) * feld
    zeilen = []
    for y in range(n):
        reihe = bytearray([0])                       # Filter 0
        qy = y // feld - rand
        for x in range(n):
            qx = x // feld - rand
            dunkel = 0 <= qy < GROESSE and 0 <= qx < GROESSE and m[qy][qx]
            reihe += b"\x00\x00\x00" if dunkel else b"\xff\xff\xff"
        zeilen.append(bytes(reihe))
    roh = zlib.compress(b"".join(zeilen), 9)

    def block(art, inhalt):
        return (struct.pack(">I", len(inhalt)) + art + inhalt
                + struct.pack(">I", zlib.crc32(art + inhalt) & 0xFFFFFFFF))

    with io.open(datei, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(block(b"IHDR", struct.pack(">IIBBBBB", n, n, 8, 2, 0, 0, 0)))
        f.write(block(b"IDAT", roh))
        f.write(block(b"IEND", b""))
    return n

if __name__ == "__main__":
    n = png(sys.argv[1], sys.argv[2])
    print(f"  {sys.argv[2]}  {n}x{n}")

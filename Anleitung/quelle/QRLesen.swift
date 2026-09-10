// Liest einen QR-Code aus einer Bilddatei - mit dem Leser, den macOS
// mitbringt. Unabhaengig von dem Kodierer, der ihn erzeugt hat: Genau darum
// geht es beim Gegenlesen.
import Foundation
import Vision
import AppKit

let pfade = Array(CommandLine.arguments.dropFirst())
var fehler = 0
for pfad in pfade {
    guard let bild = NSImage(contentsOfFile: pfad),
          let cg = bild.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("\(pfad)\tDATEI NICHT LESBAR"); fehler += 1; continue
    }
    let anfrage = VNDetectBarcodesRequest()
    anfrage.symbologies = [.qr]
    let leser = VNImageRequestHandler(cgImage: cg, options: [:])
    do {
        try leser.perform([anfrage])
        let treffer = (anfrage.results ?? []).compactMap { $0.payloadStringValue }
        if treffer.isEmpty { print("\(pfad)\tNICHTS ERKANNT"); fehler += 1 }
        else { print("\(pfad)\t\(treffer[0])") }
    } catch {
        print("\(pfad)\tFEHLER: \(error)"); fehler += 1
    }
}
exit(fehler == 0 ? 0 : 1)

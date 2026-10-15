import UIKit
import MapKit

enum Stamper {

    /// Fotoğrafın altına adres, koordinat ve tarih panelini çizer.
    static func render(base: UIImage, info: StampInfo, note: String, map: UIImage?) -> UIImage {
        let size = base.size
        let u = min(size.width, size.height) / 1000.0

        let titleFont = UIFont.systemFont(ofSize: 40 * u, weight: .bold)
        let lineFont = UIFont.systemFont(ofSize: 28 * u, weight: .medium)
        let noteFont = UIFont.systemFont(ofSize: 30 * u, weight: .semibold)

        let margin = 24 * u
        let pad = 24 * u
        let gap = 8 * u
        let mapSide: CGFloat = (map != nil) ? 240 * u : 0
        let textX = margin + pad + (mapSide > 0 ? mapSide + pad : 0)
        let textW = size.width - textX - margin - pad

        var items: [(String, UIFont, UIColor)] = []
        items.append((info.title, titleFont, .white))
        for line in info.lines {
            items.append((line, lineFont, UIColor(white: 0.92, alpha: 1)))
        }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNote.isEmpty {
            items.append(("📝 " + trimmedNote, noteFont, UIColor(red: 1.0, green: 0.84, blue: 0.3, alpha: 1)))
        }

        func height(_ text: String, _ font: UIFont) -> CGFloat {
            let rect = (text as NSString).boundingRect(
                with: CGSize(width: textW, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil)
            return ceil(rect.height)
        }

        var textH: CGFloat = 0
        for item in items { textH += height(item.0, item.1) + gap }
        textH -= gap

        let panelH = max(textH, mapSide) + pad * 2
        let panel = CGRect(x: margin,
                           y: size.height - margin - panelH,
                           width: size.width - margin * 2,
                           height: panelH)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            base.draw(in: CGRect(origin: .zero, size: size))

            UIColor(white: 0, alpha: 0.58).setFill()
            UIBezierPath(roundedRect: panel, cornerRadius: 20 * u).fill()

            if let map = map {
                let r = CGRect(x: panel.minX + pad,
                               y: panel.minY + (panelH - mapSide) / 2,
                               width: mapSide,
                               height: mapSide)
                ctx.cgContext.saveGState()
                UIBezierPath(roundedRect: r, cornerRadius: 14 * u).addClip()
                map.draw(in: r)
                ctx.cgContext.restoreGState()

                let c = CGPoint(x: r.midX, y: r.midY)
                let outer = 15 * u
                let inner = 11 * u
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(x: c.x - outer, y: c.y - outer, width: outer * 2, height: outer * 2)).fill()
                UIColor.systemRed.setFill()
                UIBezierPath(ovalIn: CGRect(x: c.x - inner, y: c.y - inner, width: inner * 2, height: inner * 2)).fill()
            }

            var y = panel.minY + (panelH - textH) / 2
            for (text, font, color) in items {
                let h = height(text, font)
                (text as NSString).draw(
                    with: CGRect(x: textX, y: y, width: textW, height: h),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: font, .foregroundColor: color],
                    context: nil)
                y += h + gap
            }
        }
    }

    /// Konumun küçük harita görüntüsünü alır (internet gerekir). 6 saniyede gelmezse nil döner.
    static func mapSnapshot(for coordinate: CLLocationCoordinate2D, completion: @escaping (UIImage?) -> Void) {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 400, longitudinalMeters: 400)
        options.size = CGSize(width: 300, height: 300)
        options.scale = 2
        options.mapType = .hybrid

        let snapshotter = MKMapSnapshotter(options: options)
        var finished = false

        snapshotter.start { snapshot, _ in
            DispatchQueue.main.async {
                if finished { return }
                finished = true
                completion(snapshot?.image)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            if finished { return }
            finished = true
            snapshotter.cancel()
            completion(nil)
        }
    }
}

extension UIImage {
    /// Yönü düzeltir ve çok büyük fotoğrafları küçültür (eski telefonlarda bellek için).
    func normalized(maxSide: CGFloat = 4032) -> UIImage {
        let s = min(1, maxSide / max(size.width, size.height))
        let newSize = CGSize(width: (size.width * s).rounded(), height: (size.height * s).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

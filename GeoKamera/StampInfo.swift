import Foundation
import CoreLocation

struct StampInfo {
    let title: String
    let lines: [String]
    let location: CLLocation?

    static func make(location: CLLocation?, placemark: CLPlacemark?, date: Date) -> StampInfo {
        var title = "Konum alınamadı"
        var lines: [String] = []

        if let p = placemark {
            let district = p.subAdministrativeArea ?? p.locality
            let titleParts = [district, p.administrativeArea, p.country]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
            var unique: [String] = []
            for part in titleParts where !unique.contains(part) { unique.append(part) }
            if !unique.isEmpty { title = unique.joined(separator: ", ") }

            var street = ""
            if let t = p.thoroughfare { street = t }
            if let n = p.subThoroughfare { street = street.isEmpty ? "No: \(n)" : "\(street) No: \(n)" }
            let addressParts = [p.subLocality, street.isEmpty ? nil : street, p.postalCode]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
            if !addressParts.isEmpty { lines.append(addressParts.joined(separator: ", ")) }
        } else if location != nil {
            title = "Adres bulunamadı (internet yok olabilir)"
        }

        if let loc = location {
            let lat = String(format: "%.6f", loc.coordinate.latitude)
            let lon = String(format: "%.6f", loc.coordinate.longitude)
            lines.append("Enlem: \(lat)°   Boylam: \(lon)°")

            var extra: [String] = []
            if loc.verticalAccuracy >= 0 {
                extra.append("Rakım: \(Int(loc.altitude.rounded())) m")
            }
            if loc.horizontalAccuracy >= 0 {
                extra.append("Doğruluk: ±\(Int(loc.horizontalAccuracy.rounded())) m")
            }
            if !extra.isEmpty { lines.append(extra.joined(separator: "   •   ")) }
        }

        lines.append(StampInfo.dateFormatter.string(from: date))
        return StampInfo(title: title, lines: lines, location: location)
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "dd.MM.yyyy  HH:mm:ss  EEEE"
        return f
    }()
}

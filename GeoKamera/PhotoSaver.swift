import UIKit
import Photos
import CoreLocation

enum PhotoSaver {
    /// Fotoğrafı konum bilgisiyle birlikte galeriye kaydeder. Sonuç ana iş parçacığında döner.
    static func save(_ image: UIImage, location: CLLocation?, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                request.location = location
                request.creationDate = Date()
            }) { success, _ in
                DispatchQueue.main.async { completion(success) }
            }
        }
    }
}

/// Filigran ayarları (Ayarlar ekranından değişir)
enum Brand {
    static var watermarkImage: UIImage? { UIImage(named: "Filigran") }

    static var watermarkEnabled: Bool {
        UserDefaults.standard.object(forKey: "wmEnabled") as? Bool ?? true
    }

    static var watermarkAlpha: CGFloat {
        CGFloat(UserDefaults.standard.object(forKey: "wmOpacity") as? Double ?? 0.45)
    }

    /// Damgaya basılacak filigran ve şeffaflığı (kapalıysa nil)
    static func currentWatermark() -> (image: UIImage?, alpha: CGFloat) {
        guard watermarkEnabled else { return (nil, 0) }
        return (watermarkImage, watermarkAlpha)
    }
}

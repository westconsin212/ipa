import SwiftUI
import AVFoundation
import Photos
import UIKit

// MARK: - Kamera modeli (AVFoundation)

final class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "konumkamera.session")
    private var configured = false

    @Published var isReady = false
    @Published var isCapturing = false
    @Published var errorText: String?

    var onPhoto: ((UIImage) -> Void)?

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted else {
                DispatchQueue.main.async { self.errorText = "Kamera izni kapalı. Ayarlardan izin verin." }
                return
            }
            self.sessionQueue.async {
                if !self.configured { self.configure() }
                if !self.session.isRunning { self.session.startRunning() }
                DispatchQueue.main.async { self.isReady = self.configured }
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(output) else {
            session.commitConfiguration()
            DispatchQueue.main.async { self.errorText = "Kamera başlatılamadı." }
            return
        }
        session.addInput(input)
        session.addOutput(output)
        session.commitConfiguration()
        configured = true
    }

    func capture() {
        guard isReady, !isCapturing else { return }
        isCapturing = true
        sessionQueue.async {
            if let connection = self.output.connection(with: .video), connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            let settings = AVCapturePhotoSettings()
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
        DispatchQueue.main.async {
            self.isCapturing = false
            if let image = image { self.onPhoto?(image) }
        }
    }
}

// MARK: - Kamera önizlemesi

final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let v = PreviewUIView()
        v.backgroundColor = .black
        v.previewLayer.session = session
        v.previewLayer.videoGravity = .resizeAspect
        return v
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
}

// MARK: - Hızlı çekim ekranı

struct QuickCameraView: View {
    @EnvironmentObject var loc: LocationManager
    @Environment(\.presentationMode) private var presentationMode
    @AppStorage("showMap") private var showMap = true

    @StateObject private var cam = CameraModel()
    @State private var savedCount = 0
    @State private var processing = 0
    @State private var thumb: UIImage?
    @State private var flash = false
    @State private var message: String?

    private static let workQueue = DispatchQueue(label: "konumkamera.quick", qos: .userInitiated)
    private let accent = Color(red: 1.0, green: 0.78, blue: 0.2)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(session: cam.session).ignoresSafeArea()

            if flash {
                Color.white.opacity(0.75).ignoresSafeArea()
            }

            VStack(spacing: 12) {
                HStack {
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill").foregroundColor(accent)
                        Text("Hızlı Çekim").fontWeight(.bold)
                        Text("• \(savedCount) kayıt").foregroundColor(Color.white.opacity(0.8))
                    }
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).frame(height: 40)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)

                if let err = cam.errorText {
                    Text(err)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(12)
                }

                Spacer()

                if let message = message {
                    Text(message)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(accent)
                        .cornerRadius(14)
                }

                liveInfo

                HStack {
                    ZStack {
                        if let t = thumb {
                            Image(uiImage: t)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipped()
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2))
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.4), lineWidth: 2)
                                .frame(width: 60, height: 60)
                        }
                        if processing > 0 {
                            ProgressView().tint(.white)
                        }
                    }
                    .frame(width: 70)

                    Spacer()

                    Button(action: shoot) {
                        ZStack {
                            Circle().stroke(Color.white, lineWidth: 5).frame(width: 84, height: 84)
                            Circle().fill(canShoot ? Color.white : Color.gray).frame(width: 68, height: 68)
                        }
                    }
                    .disabled(!canShoot)

                    Spacer()
                    Color.clear.frame(width: 70, height: 60)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            cam.onPhoto = { img in handle(img) }
            cam.start()
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { _ in }
        }
        .onDisappear { cam.stop() }
    }

    private var canShoot: Bool {
        cam.isReady && !cam.isCapturing && processing < 2
    }

    private var liveInfo: some View {
        let info = StampInfo.make(location: loc.location, placemark: loc.placemark, date: Date())
        return VStack(alignment: .leading, spacing: 3) {
            Text(loc.location == nil ? "Konum aranıyor…" : info.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
            if let c = loc.location?.coordinate {
                Text(String(format: "%.6f°, %.6f°", c.latitude, c.longitude))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.55))
        .cornerRadius(14)
        .padding(.horizontal, 16)
    }

    private func shoot() {
        guard canShoot else { return }
        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeIn(duration: 0.2)) { flash = false }
        }
        cam.capture()
    }

    private func handle(_ image: UIImage) {
        let info = StampInfo.make(location: loc.location, placemark: loc.placemark, date: Date())
        let map = showMap ? loc.mapImage : nil
        let wm = Brand.currentWatermark()
        let location = loc.location
        processing += 1

        QuickCameraView.workQueue.async {
            let base = image.normalized()
            let stamped = Stamper.render(base: base, info: info, note: "", map: map, watermark: wm.image, watermarkAlpha: wm.alpha)
            let small = stamped.normalized(maxSide: 200)
            DispatchQueue.main.async {
                PhotoSaver.save(stamped, location: location) { ok in
                    processing -= 1
                    if ok {
                        savedCount += 1
                        thumb = small
                    } else {
                        showMessage("Kaydedilemedi. Galeri iznini kontrol edin.")
                    }
                }
            }
        }
    }

    private func showMessage(_ text: String) {
        withAnimation { message = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { message = nil }
        }
    }

    private func close() {
        cam.stop()
        presentationMode.wrappedValue.dismiss()
    }
}

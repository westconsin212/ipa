import SwiftUI
import PencilKit
import Photos
import UIKit

final class CanvasHolder: ObservableObject {
    let canvas = PKCanvasView()
    let toolPicker = PKToolPicker()
}

struct EditorView: View {
    let photo: CapturedPhoto
    @Environment(\.presentationMode) private var presentationMode

    @StateObject private var holder = CanvasHolder()
    @State private var stamped: UIImage?
    @State private var mapImage: UIImage?
    @State private var showMap = true
    @State private var note = ""
    @State private var appliedNote = ""
    @State private var drawing = false
    @State private var isRendering = false
    @State private var shareImage: UIImage?
    @State private var showShare = false
    @State private var toast: String?

    private let accent = Color(red: 1.0, green: 0.78, blue: 0.2)

    private var info: StampInfo {
        StampInfo.make(location: photo.location, placemark: photo.placemark, date: photo.date)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 10) {
                topBar
                noteField
                imageArea
                bottomBar
            }

            if let toast = toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 22).padding(.vertical, 14)
                        .background(accent)
                        .cornerRadius(16)
                        .padding(.bottom, 120)
                }
                .transition(.opacity)
            }
        }
        .onAppear(perform: start)
        .sheet(isPresented: $showShare) {
            if let img = shareImage { ShareSheet(items: [img]) }
        }
    }

    // MARK: - Üst çubuk

    private var topBar: some View {
        HStack {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            Spacer()
            Text("Düzenle").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            Spacer()
            Button(action: save) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Kaydet")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 16).frame(height: 42)
                .background(accent)
                .cornerRadius(21)
            }
            .disabled(stamped == nil)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
    }

    private var noteField: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil.and.outline").foregroundColor(.gray)
            TextField("Not ekle (ör. Parsel 125, Kamera 2)", text: $note)
                .foregroundColor(.white)
                .submitLabel(.done)
                .onSubmit(applyNote)
            if note != appliedNote {
                Button("Uygula", action: applyNote)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(accent)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 14)
    }

    // MARK: - Görsel ve çizim alanı

    private var imageArea: some View {
        GeometryReader { geo in
            ZStack {
                if let img = stamped {
                    let fit = fittedSize(img.size, in: geo.size)
                    ZStack {
                        Image(uiImage: img)
                            .resizable()
                            .frame(width: fit.width, height: fit.height)
                        CanvasView(canvas: holder.canvas, toolPicker: holder.toolPicker, drawingEnabled: drawing)
                            .frame(width: fit.width, height: fit.height)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    ProgressView("Hazırlanıyor…")
                        .foregroundColor(.white)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                if isRendering && stamped != nil {
                    ProgressView().scaleEffect(1.4)
                }
            }
        }
    }

    // MARK: - Alt araç çubuğu

    private var bottomBar: some View {
        HStack(spacing: 0) {
            toolButton(icon: drawing ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle",
                       title: drawing ? "Bitti" : "Çiz",
                       active: drawing) {
                drawing.toggle()
            }
            toolButton(icon: "arrow.uturn.backward", title: "Geri Al") {
                holder.canvas.undoManager?.undo()
            }
            toolButton(icon: "trash", title: "Temizle") {
                holder.canvas.drawing = PKDrawing()
            }
            toolButton(icon: showMap ? "map.fill" : "map", title: "Harita", active: showMap) {
                showMap.toggle()
                rerender()
            }
            toolButton(icon: "square.and.arrow.up", title: "Paylaş") {
                guard stamped != nil else { return }
                shareImage = exportImage()
                showShare = true
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, drawing ? 90 : 8)
    }

    private func toolButton(icon: String, title: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 22, weight: .semibold))
                Text(title).font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(active ? accent : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
        }
    }

    // MARK: - Mantık

    private func start() {
        rerender()
        if let coord = photo.location?.coordinate {
            Stamper.mapSnapshot(for: coord) { img in
                mapImage = img
                if img != nil { rerender() }
            }
        }
    }

    private func applyNote() {
        appliedNote = note
        hideKeyboard()
        rerender()
    }

    private func rerender() {
        let base = photo.image
        let info = self.info
        let n = appliedNote
        let m = showMap ? mapImage : nil
        isRendering = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Stamper.render(base: base, info: info, note: n, map: m)
            DispatchQueue.main.async {
                stamped = result
                isRendering = false
            }
        }
    }

    private func exportImage() -> UIImage {
        guard let img = stamped else { return photo.image }
        let canvasSize = holder.canvas.bounds.size
        if canvasSize.width < 1 || holder.canvas.drawing.bounds.isEmpty { return img }

        let scale = img.size.width / canvasSize.width
        var drawingImage = UIImage()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            drawingImage = holder.canvas.drawing.image(from: CGRect(origin: .zero, size: canvasSize), scale: scale)
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: img.size, format: format).image { _ in
            img.draw(in: CGRect(origin: .zero, size: img.size))
            drawingImage.draw(in: CGRect(origin: .zero, size: img.size))
        }
    }

    private func save() {
        guard stamped != nil else { return }
        let finalImage = exportImage()
        let location = photo.location
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { showToast("Galeri izni yok. Ayarlardan izin verin.") }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest.creationRequestForAsset(from: finalImage)
                request.location = location
                request.creationDate = Date()
            }) { success, _ in
                DispatchQueue.main.async {
                    showToast(success ? "✓ Galeriye kaydedildi" : "Kaydedilemedi")
                }
            }
        }
    }

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { toast = nil }
        }
    }

    private func fittedSize(_ size: CGSize, in box: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return .zero }
        let s = min(box.width / size.width, box.height / size.height)
        return CGSize(width: floor(size.width * s), height: floor(size.height * s))
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

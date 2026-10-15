import SwiftUI
import PencilKit
import UIKit

enum EditTool: String, CaseIterable {
    case none, pen, arrow, circle, rect, text

    var icon: String {
        switch self {
        case .none: return "hand.point.up.left"
        case .pen: return "pencil.tip"
        case .arrow: return "arrow.up.right"
        case .circle: return "circle"
        case .rect: return "square"
        case .text: return "textformat"
        }
    }

    var title: String {
        switch self {
        case .none: return "Seç"
        case .pen: return "Kalem"
        case .arrow: return "Ok"
        case .circle: return "Daire"
        case .rect: return "Kare"
        case .text: return "Yazı"
        }
    }

    var shapeKind: Markup.Kind? {
        switch self {
        case .arrow: return .arrow
        case .circle: return .circle
        case .rect: return .rect
        case .text: return .text
        default: return nil
        }
    }
}

struct EditorView: View {
    let photo: CapturedPhoto
    @Environment(\.presentationMode) private var presentationMode

    @StateObject private var model = EditorModel()
    @State private var stamped: UIImage?
    @State private var mapImage: UIImage?
    @State private var showMap = true
    @State private var note = ""
    @State private var appliedNote = ""
    @State private var tool: EditTool = .none
    @State private var colorIndex = 0
    @State private var isRendering = false
    @State private var shareImage: UIImage?
    @State private var showShare = false
    @State private var toast: String?

    // Yazı ekleme
    @State private var textPoint: CGPoint?
    @State private var textInput = ""
    @FocusState private var textFocused: Bool

    private let accent = Color(red: 1.0, green: 0.78, blue: 0.2)
    private let palette: [UIColor] = [.systemRed, .systemYellow, .white, .systemGreen, .systemBlue, .black]

    private var info: StampInfo {
        StampInfo.make(location: photo.location, placemark: photo.placemark, date: photo.date)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 8) {
                topBar
                noteField
                imageArea
                toolRow
                if tool.shapeKind != nil { colorRow }
                actionRow
            }

            if textPoint != nil { textInputOverlay }

            if let toast = toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 22).padding(.vertical, 14)
                        .background(accent)
                        .cornerRadius(16)
                        .padding(.bottom, 140)
                }
                .transition(.opacity)
            }
        }
        .onAppear(perform: start)
        .sheet(isPresented: $showShare) {
            if let img = shareImage { ShareSheet(items: [img]) }
        }
    }

    // MARK: - Üst kısım

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
            Image(systemName: "note.text").foregroundColor(.gray)
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
        .frame(height: 42)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 14)
    }

    // MARK: - Görsel alanı

    private var imageArea: some View {
        GeometryReader { geo in
            ZStack {
                if let img = stamped {
                    let fit = fittedSize(img.size, in: geo.size)
                    ZStack {
                        Image(uiImage: img)
                            .resizable()
                            .frame(width: fit.width, height: fit.height)

                        MarkupLayer(markups: model.markups + (model.draft.map { [$0] } ?? []))
                            .frame(width: fit.width, height: fit.height)
                            .allowsHitTesting(false)

                        CanvasView(canvas: model.canvas, toolPicker: model.toolPicker, drawingEnabled: tool == .pen)
                            .frame(width: fit.width, height: fit.height)

                        if tool.shapeKind != nil {
                            Color.clear
                                .contentShape(Rectangle())
                                .frame(width: fit.width, height: fit.height)
                                .gesture(shapeGesture(fit: fit))
                        }
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

    private func shapeGesture(fit: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                guard let kind = tool.shapeKind, kind != .text else { return }
                model.draft = Markup(kind: kind,
                                     start: normalize(v.startLocation, fit),
                                     end: normalize(v.location, fit),
                                     color: palette[colorIndex])
            }
            .onEnded { v in
                guard let kind = tool.shapeKind else { return }
                let s = normalize(v.startLocation, fit)
                let e = normalize(v.location, fit)
                model.draft = nil
                if kind == .text {
                    textInput = ""
                    textPoint = s
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { textFocused = true }
                    return
                }
                let dist = hypot((e.x - s.x) * fit.width, (e.y - s.y) * fit.height)
                if dist > 12 {
                    model.add(Markup(kind: kind, start: s, end: e, color: palette[colorIndex]))
                }
            }
    }

    // MARK: - Araç çubukları

    private var toolRow: some View {
        HStack(spacing: 4) {
            ForEach([EditTool.pen, .arrow, .circle, .rect, .text], id: \.self) { t in
                Button(action: { tool = (tool == t) ? .none : t }) {
                    VStack(spacing: 3) {
                        Image(systemName: t.icon).font(.system(size: 20, weight: .semibold))
                        Text(t.title).font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(tool == t ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(tool == t ? accent : Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal, 12)
    }

    private var colorRow: some View {
        HStack(spacing: 14) {
            ForEach(palette.indices, id: \.self) { i in
                Circle()
                    .fill(Color(palette[i]))
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(Color.white, lineWidth: colorIndex == i ? 3 : 1))
                    .scaleEffect(colorIndex == i ? 1.15 : 1)
                    .onTapGesture { colorIndex = i }
            }
        }
        .padding(.vertical, 2)
    }

    private var actionRow: some View {
        HStack(spacing: 0) {
            actionButton(icon: "arrow.uturn.backward", title: "Geri Al") { model.undo() }
            actionButton(icon: "trash", title: "Temizle") { model.clear() }
            actionButton(icon: showMap ? "map.fill" : "map", title: "Harita", active: showMap) {
                showMap.toggle()
                rerender()
            }
            actionButton(icon: "square.and.arrow.up", title: "Paylaş") {
                guard stamped != nil else { return }
                shareImage = exportImage()
                showShare = true
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, tool == .pen ? 90 : 6)
    }

    private func actionButton(icon: String, title: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold))
                Text(title).font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(active ? accent : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
        }
    }

    // MARK: - Yazı ekleme penceresi

    private var textInputOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { textPoint = nil }
            VStack(spacing: 14) {
                Text("Yazı ekle").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                TextField("Yazınızı girin", text: $textInput)
                    .focused($textFocused)
                    .submitLabel(.done)
                    .onSubmit(addText)
                    .padding(12)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                HStack(spacing: 12) {
                    Button("İptal") { textPoint = nil }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(Color.white.opacity(0.15)).cornerRadius(10)
                    Button("Ekle", action: addText)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(accent).cornerRadius(10)
                }
                .font(.system(size: 16, weight: .bold))
            }
            .padding(20)
            .background(Color(white: 0.12))
            .cornerRadius(18)
            .padding(.horizontal, 30)
        }
    }

    private func addText() {
        let t = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if let p = textPoint, !t.isEmpty {
            model.add(Markup(kind: .text, start: p, end: p, color: palette[colorIndex], text: t))
        }
        textPoint = nil
        textFocused = false
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
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        rerender()
    }

    private func rerender() {
        let base = photo.image
        let info = self.info
        let n = appliedNote
        let m = showMap ? mapImage : nil
        let wm = Brand.currentWatermark()
        isRendering = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Stamper.render(base: base, info: info, note: n, map: m, watermark: wm.image, watermarkAlpha: wm.alpha)
            DispatchQueue.main.async {
                stamped = result
                isRendering = false
            }
        }
    }

    private func exportImage() -> UIImage {
        guard let img = stamped else { return photo.image }
        let canvasSize = model.canvas.bounds.size
        let markups = model.markups
        let hasPen = !model.canvas.drawing.strokes.isEmpty && canvasSize.width > 1
        if markups.isEmpty && !hasPen { return img }

        var penImage: UIImage?
        if hasPen {
            let scale = img.size.width / canvasSize.width
            UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
                penImage = model.canvas.drawing.image(from: CGRect(origin: .zero, size: canvasSize), scale: scale)
            }
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: img.size, format: format).image { ctx in
            img.draw(in: CGRect(origin: .zero, size: img.size))
            MarkupRenderer.draw(markups, in: ctx.cgContext, size: img.size)
            penImage?.draw(in: CGRect(origin: .zero, size: img.size))
        }
    }

    private func save() {
        guard stamped != nil else { return }
        PhotoSaver.save(exportImage(), location: photo.location) { ok in
            showToast(ok ? "✓ Galeriye kaydedildi" : "Kaydedilemedi. Galeri iznini kontrol edin.")
        }
    }

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { toast = nil }
        }
    }

    private func normalize(_ p: CGPoint, _ fit: CGSize) -> CGPoint {
        CGPoint(x: min(max(p.x / fit.width, 0), 1), y: min(max(p.y / fit.height, 0), 1))
    }

    private func fittedSize(_ size: CGSize, in box: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0, box.width > 0, box.height > 0 else { return CGSize(width: 1, height: 1) }
        let s = min(box.width / size.width, box.height / size.height)
        return CGSize(width: floor(size.width * s), height: floor(size.height * s))
    }
}

import SwiftUI
import CoreLocation
import UIKit

struct CapturedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
    let location: CLLocation?
    let placemark: CLPlacemark?
    let date: Date
}

struct ContentView: View {
    @EnvironmentObject var loc: LocationManager

    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var showQuick = false
    @State private var showSettings = false
    @State private var captured: CapturedPhoto?

    private let accent = Color(red: 1.0, green: 0.78, blue: 0.2)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.08, green: 0.10, blue: 0.16), Color.black],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                HStack(spacing: 10) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(accent)
                    Text("Konum Kamera")
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 10)

                if let logo = Brand.watermarkImage {
                    Image(uiImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 70)
                        .padding(.horizontal, 30)
                }

                locationCard

                Spacer()

                Button(action: openCamera) {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill").font(.system(size: 26, weight: .bold))
                        Text("Fotoğraf Çek").font(.system(size: 24, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 74)
                    .background(accent)
                    .cornerRadius(22)
                }

                Button(action: { showQuick = true }) {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.fill").font(.system(size: 20, weight: .bold))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Hızlı Çekim").font(.system(size: 19, weight: .bold))
                            Text("Art arda çek, damgalı direkt galeriye").font(.system(size: 12))
                                .foregroundColor(Color.white.opacity(0.75))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(Color(red: 0.85, green: 0.2, blue: 0.2))
                    .cornerRadius(20)
                }

                Button(action: { showLibrary = true }) {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle").font(.system(size: 20, weight: .semibold))
                        Text("Galeriden Seç").font(.system(size: 19, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(18)
                }

                Text("Galeriden seçilen fotoğrafa şu anki konumun eklenir.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 20)
        }
        .onAppear { loc.start() }
        .fullScreenCover(isPresented: $showCamera) {
            ImagePicker(source: .camera,
                        onPick: { img in handlePicked(img) ; showCamera = false },
                        onCancel: { showCamera = false })
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showLibrary) {
            ImagePicker(source: .photoLibrary,
                        onPick: { img in handlePicked(img) ; showLibrary = false },
                        onCancel: { showLibrary = false })
        }
        .fullScreenCover(item: $captured) { photo in
            EditorView(photo: photo)
        }
        .background(
            EmptyView()
                .fullScreenCover(isPresented: $showQuick) {
                    QuickCameraView().environmentObject(loc)
                }
        )
        .background(
            EmptyView()
                .sheet(isPresented: $showSettings) { SettingsView() }
        )
    }

    // MARK: - Konum kartı

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "location.fill").foregroundColor(accent)
                Text("Şu anki konum")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.gray)
                Spacer()
                if loc.location != nil {
                    Circle().fill(Color.green).frame(width: 9, height: 9)
                    Text("Canlı").font(.caption).foregroundColor(.green)
                }
            }

            if loc.isDenied {
                Text("Konum izni kapalı")
                    .font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                Text("Ayarlar > Konum Kamera > Konum bölümünden \"Uygulamayı Kullanırken\" seçeneğini açın.")
                    .font(.system(size: 15)).foregroundColor(.gray)
                Button("Ayarları Aç") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(accent)
            } else {
                let info = StampInfo.make(location: loc.location, placemark: loc.placemark, date: Date())
                Text(loc.location == nil ? "Konum aranıyor…" : info.title)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(info.lines.dropLast().enumerated()), id: \.offset) { item in
                    Text(item.element)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .cornerRadius(20)
    }

    // MARK: - İşlemler

    private func openCamera() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            showCamera = true
        }
    }

    private func handlePicked(_ image: UIImage) {
        let photo = CapturedPhoto(image: image.normalized(),
                                  location: loc.location,
                                  placemark: loc.placemark,
                                  date: Date())
        // Kamera kapanma animasyonu bitsin, sonra düzenleyiciyi aç
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            captured = photo
        }
    }
}

import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) private var presentationMode
    @AppStorage("wmEnabled") private var wmEnabled = true
    @AppStorage("wmOpacity") private var wmOpacity = 0.45
    @AppStorage("showMap") private var showMap = true

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Filigran"),
                        footer: Text("MASSAKA 34/06/16 SHOP yazısı fotoğrafın ortasına yarı saydam basılır.")) {
                    Toggle("Filigranı göster", isOn: $wmEnabled)
                    if wmEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Belirginlik: %\(Int(wmOpacity * 100))")
                                .font(.subheadline)
                            Slider(value: $wmOpacity, in: 0.15...0.9, step: 0.05)
                        }
                        if let wm = Brand.watermarkImage {
                            ZStack {
                                LinearGradient(colors: [Color(red: 0.55, green: 0.7, blue: 0.85),
                                                        Color(red: 0.45, green: 0.55, blue: 0.3)],
                                               startPoint: .top, endPoint: .bottom)
                                Image(uiImage: wm)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(.horizontal, 24)
                                    .opacity(wmOpacity)
                            }
                            .frame(height: 120)
                            .cornerRadius(10)
                        }
                    }
                }

                Section(header: Text("Hızlı Çekim")) {
                    Toggle("Damgada haritayı göster", isOn: $showMap)
                }
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

import SwiftUI

public struct VisualizerView: View {
    public let isPlaying: Bool
    public var barCount: Int = 4

    @State private var animate = false

    public init(isPlaying: Bool, barCount: Int = 4) {
        self.isPlaying = isPlaying
        self.barCount = barCount
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "06B6D4"), Color(hex: "6366F1")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(
                        width: 3,
                        height: isPlaying ? (animate ? CGFloat(Int.random(in: 6...18)) : CGFloat(Int.random(in: 4...12))) : 4
                    )
                    .animation(
                        isPlaying
                            ? Animation.easeInOut(duration: 0.35).repeatForever().delay(Double(i) * 0.1)
                            : .default,
                        value: animate
                    )
            }
        }
        .frame(height: 20)
        .onAppear {
            if isPlaying {
                animate.toggle()
            }
        }
        .onChange(of: isPlaying) { playing in
            if playing {
                animate = true
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

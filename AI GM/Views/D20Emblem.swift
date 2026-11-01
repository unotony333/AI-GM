//
//  D20Emblem.swift
//  AI GM
//
//  與 App Icon 相同的二十面骰：羊皮紙面、黃銅框、由內透出的燭光。
//

import SwiftUI

struct D20Emblem: View, Animatable {
    /// 0 為熄滅（尚未開始），1 為點亮
    var glow: Double = 1

    var animatableData: Double {
        get { glow }
        set { glow = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            func point(_ unit: CGPoint) -> CGPoint {
                CGPoint(x: center.x + unit.x * radius, y: center.y - unit.y * radius)
            }
            func polygon(_ units: [CGPoint]) -> Path {
                var path = Path()
                path.addLines(units.map(point))
                path.closeSubpath()
                return path
            }

            for face in D20Geometry.faces {
                context.fill(polygon(face.points), with: .color(D20Geometry.faceColor(face.brightness, glow: glow)))
            }

            let outline = polygon(D20Geometry.hexagon)
            var lit = context
            lit.clip(to: outline)
            lit.blendMode = .screen
            let lightCenter = point(CGPoint(x: -0.08, y: 0.05))
            lit.fill(outline, with: .radialGradient(
                Gradient(colors: [
                    Color(hex: 0xFFD58A, opacity: 0.55 * glow),
                    Palette.candle.opacity(0.18 * glow),
                    .clear
                ]),
                center: lightCenter,
                startRadius: 0,
                endRadius: radius * 1.05
            ))

            let edge = radius * 0.055
            let frame = Palette.candle.opacity(0.55 + 0.45 * glow)
            for face in D20Geometry.faces {
                context.stroke(polygon(face.points), with: .color(frame),
                               style: StrokeStyle(lineWidth: edge, lineCap: .round, lineJoin: .round))
            }
            context.stroke(outline, with: .color(frame),
                           style: StrokeStyle(lineWidth: edge * 1.35, lineCap: .round, lineJoin: .round))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// AI 正在產生內容時，骰子像燭火一樣明暗呼吸。
struct ThinkingDie: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLit = false

    var body: some View {
        D20Emblem(glow: isLit ? 1 : 0.2)
            .onAppear {
                guard !reduceMotion else {
                    isLit = true
                    return
                }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    isLit = true
                }
            }
    }
}

private enum D20Geometry {
    struct Face {
        let points: [CGPoint]
        let brightness: Double
    }

    private static let s3 = sqrt(3.0) / 2

    /// 正六邊形外框（y 軸向上，半徑 1）
    static let hexagon = [
        CGPoint(x: 0, y: 1), CGPoint(x: s3, y: 0.5), CGPoint(x: s3, y: -0.5),
        CGPoint(x: 0, y: -1), CGPoint(x: -s3, y: -0.5), CGPoint(x: -s3, y: 0.5)
    ]

    private static let triangle = [
        CGPoint(x: 0, y: 0.56), CGPoint(x: 0.54, y: -0.37), CGPoint(x: -0.54, y: -0.37)
    ]

    /// 光源在左上方，亮度依面向決定。
    static let faces: [Face] = {
        let h = hexagon, t = triangle
        return [
            Face(points: [t[0], t[1], t[2]], brightness: 1.00),
            Face(points: [h[0], h[5], t[0]], brightness: 0.93),
            Face(points: [h[0], h[1], t[0]], brightness: 0.72),
            Face(points: [h[5], t[0], t[2]], brightness: 0.84),
            Face(points: [h[1], t[0], t[1]], brightness: 0.58),
            Face(points: [h[5], h[4], t[2]], brightness: 0.62),
            Face(points: [h[1], h[2], t[1]], brightness: 0.38),
            Face(points: [h[4], h[3], t[2]], brightness: 0.46),
            Face(points: [h[2], h[3], t[1]], brightness: 0.30),
            Face(points: [t[2], t[1], h[3]], brightness: 0.52)
        ]
    }()

    /// 在暗褐與羊皮紙色之間插值；熄滅時整體壓暗。
    static func faceColor(_ brightness: Double, glow: Double) -> Color {
        let shade: (r: Double, g: Double, b: Double) = (0x4A, 0x34, 0x20)
        let light: (r: Double, g: Double, b: Double) = (0xEF, 0xE3, 0xC8)
        let t = brightness * (0.45 + 0.55 * glow)
        return Color(
            .sRGB,
            red: (shade.r + (light.r - shade.r) * t) / 255,
            green: (shade.g + (light.g - shade.g) * t) / 255,
            blue: (shade.b + (light.b - shade.b) * t) / 255
        )
    }
}

#Preview {
    HStack(spacing: 24) {
        D20Emblem().frame(width: 120)
        D20Emblem(glow: 0).frame(width: 120)
    }
    .padding(40)
    .background(Palette.felt)
}

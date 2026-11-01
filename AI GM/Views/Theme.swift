//
//  Theme.swift
//  AI GM
//
//  色彩、字體與背景：深綠桌布 + 燭光，GM 敘事以宋體排版。
//

import SwiftUI
import CoreText
import UIKit
internal import Combine

// MARK: - Palette

enum Palette {
    /// 桌布底色
    static let felt = Color(hex: 0x13261F)
    static let feltDeep = Color(hex: 0x0B1813)
    /// 卡片、浮起的區塊
    static let feltRaised = Color(hex: 0x1B342A)
    /// 輸入框
    static let feltSunken = Color(hex: 0x0E1E18)
    static let hairline = Color(hex: 0xEFE3C8).opacity(0.12)

    /// 主要文字、GM 敘事
    static let vellum = Color(hex: 0xEFE3C8)
    /// 次要文字
    static let sage = Color(hex: 0xA3B0A4)
    static let sageDim = Color(hex: 0x6F8074)

    /// 主要按鈕、重點
    static let candle = Color(hex: 0xE0A84E)
    static let candleInk = Color(hex: 0x2A1A08)
    /// HP、房主印記
    static let wax = Color(hex: 0xC2483A)
    /// 已確認
    static let moss = Color(hex: 0x8CC29F)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Serif Font

/// 宋體（Songti TC）不是 iOS 內建字體，第一次使用時向系統下載，下載完成前退回系統字體。
@MainActor
final class SerifFontLoader: ObservableObject {
    static let shared = SerifFontLoader()

    @Published private(set) var isReady: Bool

    private static let postScriptNames = [SerifStyle.regularName, SerifStyle.boldName]
    private var isLoading = false

    private init() {
        isReady = Self.isInstalled
    }

    func loadIfNeeded() {
        guard !isReady, !isLoading else { return }
        isLoading = true

        Self.requestDownload(Self.postScriptNames) {
            Task { @MainActor in
                let loader = SerifFontLoader.shared
                loader.isLoading = false
                loader.isReady = Self.isInstalled
            }
        }
    }

    private static var isInstalled: Bool {
        postScriptNames.allSatisfy { UIFont(name: $0, size: 12) != nil }
    }

    // CoreText 會在背景執行緒呼叫進度回呼，所以這裡不能隔離在 MainActor。
    nonisolated private static func requestDownload(_ names: [String], completion: @escaping @Sendable () -> Void) {
        let descriptors = names.map {
            CTFontDescriptorCreateWithAttributes([kCTFontNameAttribute: $0] as CFDictionary)
        }

        CTFontDescriptorMatchFontDescriptorsWithProgressHandler(descriptors as CFArray, nil) { state, _ in
            if state == .didFinish {
                completion()
            }
            return true
        }
    }
}

struct SerifStyle {
    static let regularName = "STSongti-TC-Regular"
    static let boldName = "STSongti-TC-Bold"

    let size: CGFloat
    let isBold: Bool
    let textStyle: Font.TextStyle

    /// GM 敘事內文
    static let narration = SerifStyle(size: 18, isBold: false, textStyle: .body)
    /// 已確認的行動引文
    static let quote = SerifStyle(size: 16, isBold: false, textStyle: .callout)
    /// 區塊標題
    static let heading = SerifStyle(size: 20, isBold: true, textStyle: .title3)
    /// 房間名稱
    static let title = SerifStyle(size: 24, isBold: true, textStyle: .title2)
    /// 大廳標語
    static let display = SerifStyle(size: 44, isBold: true, textStyle: .largeTitle)

    var font: Font {
        .custom(isBold ? Self.boldName : Self.regularName, size: size, relativeTo: textStyle)
    }

    var fallback: Font {
        .system(size: size, weight: isBold ? .bold : .regular, design: .serif)
    }
}

private struct SerifFontModifier: ViewModifier {
    @ObservedObject private var loader = SerifFontLoader.shared
    let style: SerifStyle

    func body(content: Content) -> some View {
        content.font(loader.isReady ? style.font : style.fallback)
    }
}

extension View {
    func serifFont(_ style: SerifStyle) -> some View {
        modifier(SerifFontModifier(style: style))
    }
}

// MARK: - Felt Background

/// 深綠桌布：頂部一盞燈，四周暗角，再疊一層細緻絨毛顆粒。
struct FeltBackground: View {
    var body: some View {
        ZStack {
            Palette.felt

            RadialGradient(
                colors: [Palette.candle.opacity(0.10), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 520
            )

            Image(.feltGrain)
                .resizable(resizingMode: .tile)
                .opacity(0.7)

            RadialGradient(
                colors: [.clear, Palette.feltDeep.opacity(0.75)],
                center: .center,
                startRadius: 220,
                endRadius: 720
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

//
//  MessageBubbleView.swift
//  AI GM
//
//  Created by tony on 2026/4/6.
//

import SwiftUI

/// 冒險紀錄的一則項目：GM 敘事像書頁一樣排版，玩家與系統訊息退居旁註。
struct MessageBubbleView: View {
    let message: CampaignMessage

    var body: some View {
        switch message.kind {
        case .opening, .narration, .ending:
            narration
        case .player:
            playerNote
        case .system:
            systemNote
        }
    }

    // MARK: - GM Narration

    private var chapterTitle: String {
        if message.kind == .opening {
            return "序章"
        }
        if message.kind == .ending {
            return "終章"
        }
        if let roundNumber = message.roundNumber {
            return "第 \(roundNumber) 回合"
        }
        return messageKindLabel(message.kind)
    }

    private var narration: some View {
        VStack(alignment: .leading, spacing: 16) {
            chapterMarker

            Text(message.text)
                .serifFont(.narration)
                .foregroundStyle(Palette.vellum)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if !message.outcomes.isEmpty {
                outcomeList
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chapterMarker: some View {
        HStack(spacing: 12) {
            ornamentRule(leading: true)

            HStack(spacing: 8) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 5))
                Text(chapterTitle)
                    .font(.footnote.weight(.semibold))
                    .tracking(1)
                Image(systemName: "diamond.fill")
                    .font(.system(size: 5))
            }
            .foregroundStyle(Palette.candle)
            .fixedSize()

            ornamentRule(leading: false)
        }
        .accessibilityElement(children: .combine)
    }

    private func ornamentRule(leading: Bool) -> some View {
        LinearGradient(
            colors: [Palette.candle.opacity(0), Palette.candle.opacity(0.45)],
            startPoint: leading ? .leading : .trailing,
            endPoint: leading ? .trailing : .leading
        )
        .frame(height: 1)
    }

    // MARK: - Round Outcomes

    private var outcomeList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(message.outcomes) { outcome in
                VStack(alignment: .leading, spacing: 4) {
                    if let checkSummary = outcome.checkSummary, let check = outcome.check {
                        Text("\(checkSummary)，\(checkResult(check))")
                    }

                    if let hpSummary = outcome.hpSummary {
                        Text(hpSummary)
                            .foregroundStyle(outcome.hpChange < 0 ? Palette.ember : Palette.moss)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .font(.footnote)
        .foregroundStyle(Palette.vellum.opacity(0.85))
        .fixedSize(horizontal: false, vertical: true)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.feltSunken, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
    }

    private func checkResult(_ check: AbilityCheck) -> Text {
        Text(check.isSuccess ? "成功" : "失敗")
            .fontWeight(.semibold)
            .foregroundStyle(check.isSuccess ? Palette.moss : Palette.ember)
    }

    // MARK: - Player / System

    private var playerNote: some View {
        HStack {
            Spacer(minLength: 48)

            VStack(alignment: .trailing, spacing: 4) {
                Text(messageKindLabel(message.kind))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.sage)

                Text(message.text)
                    .font(.callout)
                    .foregroundStyle(Palette.vellum)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Palette.feltRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Palette.hairline, lineWidth: 1)
                    )
            }
        }
    }

    private var systemNote: some View {
        Text(message.text)
            .font(.footnote)
            .foregroundStyle(Palette.sage)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
    }
}

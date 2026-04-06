//
//  MessageBubbleView.swift
//  AI GM
//
//  Created by tony on 2026/4/6.
//

import SwiftUI

struct MessageBubbleView: View {
    let message: CampaignMessage

    private var isPlayer: Bool {
        message.kind == .player
    }

    var body: some View {
        HStack {
            if isPlayer { Spacer(minLength: 30) }

            VStack(alignment: .leading, spacing: 6) {
                Text(messageKindLabel(message.kind))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isPlayer ? Color.white.opacity(0.8) : Color.orange.opacity(0.9))

                Text(message.text)
                    .font(.body)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: 320, alignment: .leading)
            .background(isPlayer ? Color.pink.opacity(0.45) : Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if !isPlayer { Spacer(minLength: 30) }
        }
    }
}

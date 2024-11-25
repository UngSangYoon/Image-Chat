//
//  ChatBubble.swift
//  llava-ios
//
//  Created by 윤웅상 on 11/2/24.
//

import SwiftUI

struct ChatBubble: View {
    var message: ChatMessage
    var isLoading: Bool

    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }

            VStack(alignment: message.isUser ? .trailing : .leading) {
                if let image = message.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if isLoading {
                    LoadingBubble()
                        .frame(height: 21)
                        .padding(10)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                } else if !message.text.isEmpty {
                    Text(message.text)
                        .padding(10)
                        .foregroundColor(message.isUser ? .white : .black)
                        .background(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                        .cornerRadius(12)
                }
            }
            .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)

            if !message.isUser {
                Spacer()
            }
        }
        .padding(message.isUser ? .leading : .trailing, 60)
        .padding(.horizontal, 10)
    }
}

struct LoadingBubble: View {
    @State private var opacity: Double = 0.3
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Color.gray).frame(width: 8, height: 8)
            Circle().fill(Color.gray).frame(width: 8, height: 8)
            Circle().fill(Color.gray).frame(width: 8, height: 8)
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                opacity = 1.0
            }
        }
    }
}

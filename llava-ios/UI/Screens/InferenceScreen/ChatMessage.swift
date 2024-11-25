//
//  ChatMessage.swift
//  llava-ios
//
//  Created by 윤웅상 on 11/2/24.
//
import Foundation
import SwiftUI

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let image: UIImage?
    let isUser: Bool

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        return lhs.id == rhs.id &&
               lhs.text == rhs.text &&
               lhs.image == rhs.image &&
               lhs.isUser == rhs.isUser
    }
}

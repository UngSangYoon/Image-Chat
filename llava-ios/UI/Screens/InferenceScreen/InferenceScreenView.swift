//
//  InferenceScreenView.swift
//  llava-ios
//
//  Created by 윤웅상 on 11/2/24.

import SwiftUI
import PhotosUI

struct InferenceScreenView: View {
    @StateObject var appstate: AppState
    @State private var messageText = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showingImagePicker = false
    @State private var showingCameraPicker = false
    @State private var showPickerOptions = false
    @FocusState private var focusedField: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(appstate.messages) { message in
                            ChatBubble(message: message, isLoading: false)
                        }
                        if appstate.loadingState != .idle {
                            ChatBubble(message: ChatMessage(text: "...", image: nil, isUser: false), isLoading: true)
                        }
                    }
                    .id("chatHistory")
                }
                .scrollDisabled(appstate.loadingState != .idle) // 스크롤 비활성화
                .refreshable {
                    if appstate.loadingState == .idle { // loadingState 체크
                        await appstate.clear()
                    }
                }
                .onChange(of: appstate.messages) { _ in
                    if let lastMessage = appstate.messages.last {
                        scrollViewProxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            
            Divider()
            
            if let selectedImage = selectedImage {
                HStack {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipped()
                        .cornerRadius(8)
                        .overlay(
                            Button(action: { removeSelectedImage() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color(UIColor.secondarySystemBackground))
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                                    .padding(4)
                            }
                            .offset(x: -1, y: -1),
                            alignment: .topTrailing
                        )
                    Spacer()
                }
                .padding(8)
                .background(Color(UIColor.secondarySystemBackground))
            }
            
            HStack {
                Button(action: { showPickerOptions = true }) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 24))
                }
                .padding(.horizontal, 8)
                .confirmationDialog("Select Image Source", isPresented: $showPickerOptions) {
                    Button("Photo Library") { showingImagePicker = true }
                    Button("Camera") { showingCameraPicker = true }
                    Button("Cancel", role: .cancel) {}
                }
                .disabled(appstate.hasImageEmbedding) // 사진 컨텍스트가 있으면 비활성화
                
                TextField(
                    appstate.loadingState == .embeddingImage ? "이미지 파악 중..." :
                    appstate.loadingState == .generatingResponse ? "답변 생성 중..." :
                    appstate.loadingState == .reloadingModel ? "모델 재로딩 중..." :
                    "메세지를 입력하세요",
                    text: $messageText
                )
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(appstate.loadingState != .idle)
                .focused($focusedField)
                .padding(.vertical, 8)
                
                Button("전송") {
                    sendMessage()
                }
                .disabled(shouldDisableSendButton()) // 버튼 활성화 조건 수정
            }
            .padding(.horizontal)
            .background(Color(UIColor.secondarySystemBackground))
        }
        .onAppear {
            Task {
                await appstate.preInit()
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showingCameraPicker) {
            CameraPicker(selectedImage: $selectedImage)
        }
    }
    
    private func sendMessage() {
        let textToSend = messageText
        let imageToSend = selectedImage
        
        Task {
            messageText = ""
            selectedImage = nil
            focusedField = false
            await appstate.complete(text: textToSend, img: imageToSend)
        }
    }

    private func removeSelectedImage() {
        selectedImage = nil
    }
    
    private func shouldDisableSendButton() -> Bool {
        // 사진 컨텍스트가 없으면 반드시 이미지가 포함되어야 전송 가능
        if !appstate.hasImageEmbedding {
            return selectedImage == nil || appstate.loadingState != .idle
        }
        // 일반 조건: 텍스트가 비어 있거나 로딩 상태가 idle가 아닐 때 비활성화
        return messageText.isEmpty || appstate.loadingState != .idle
    }
}

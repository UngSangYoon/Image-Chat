//
//  ModelSelectionView.swift
//  llava-ios
//
//  Created by 윤웅상 on 11/18/24.
//

import SwiftUI

struct ModelSelectionView: View {
    @Binding var showingModelSelection: Bool
    @ObservedObject var appstate: AppState

    var body: some View {
        VStack {
            Text("모델을 선택하세요")
                .font(.title)
                .padding()

            ForEach(appstate.downloadedModels) { model in
                ModelRowView(
                    model: model,
                    appstate: appstate,
                    showingModelSelection: $showingModelSelection
                )
                .padding(.vertical, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
        .ignoresSafeArea()
    }
}

struct ModelRowView: View {
    @StateObject private var downloadState = DownloadState()
    let model: LlamaModel
    @ObservedObject var appstate: AppState
    @Binding var showingModelSelection: Bool

    @State private var showAlert: Bool = false // 경고 메시지 상태
    @State private var alertMessage: String = "" // 동적 경고 메시지

    var body: some View {
        VStack {
            if model.status == "downloaded" {
                Button(action: {
                    appstate.selectedModel = model
                    showingModelSelection = false
                    appstate.initializeModel()
                }) {
                    Text("Load \(model.name)")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(appstate.isDownloading)
            } else {
                VStack {
                    Button(action: {
                        if let reason = shouldDisableButton() {
                            alertMessage = reason
                            showAlert = true // 경고 메시지 띄움
                        } else {
                            appstate.isDownloading = true
                            downloadState.download(
                                modelName: model.name,
                                modelUrl: model.url,
                                filename: model.filename
                            ) { success in
                                appstate.isDownloading = false
                                if success {
                                    appstate.loadModelsFromDisk()
                                }
                            }
                        }
                    }) {
                        Text("Download \(model.name)")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(appstate.isDownloading || shouldDisableButton() != nil ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(appstate.isDownloading) // 다운로드 상태에만 의존
                    .alert(isPresented: $showAlert) {
                        Alert(
                            title: Text("다운로드 불가"),
                            message: Text(alertMessage),
                            dismissButton: .default(Text("확인"))
                        )
                    }

                    if downloadState.status == "downloading" {
                        ProgressView(value: downloadState.progress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding()
                    }
                }
            }
        }
    }

    private func shouldDisableButton() -> String? {
        let ram = appstate.deviceRAMSize

        if ram < 5 {
            return "6GB 이상의 RAM을 가진 기기가 필요합니다."
        }

        if model.name.contains("FP16") && ram < 8 {
            return "8GB 이상의 RAM을 가진 기기가 필요합니다."
        }

        return nil // 다운로드 가능
    }
}

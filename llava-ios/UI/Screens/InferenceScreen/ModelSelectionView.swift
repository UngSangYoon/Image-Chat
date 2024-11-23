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
            Text("Select a Model")
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
                .disabled(appstate.isDownloading) // 다른 모델 다운로드 중일 때 비활성화
            } else {
                VStack {
                    Button(action: {
                        appstate.isDownloading = true // 다운로드 시작
                        downloadState.download(
                            modelName: model.name,
                            modelUrl: model.url,
                            filename: model.filename
                        ) { success in
                            appstate.isDownloading = false // 다운로드 종료
                            if success {
                                appstate.loadModelsFromDisk()
                            }
                        }
                    }) {
                        Text("Download \(model.name)")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(appstate.isDownloading ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(appstate.isDownloading) // 다른 모델 다운로드 중일 때 비활성화

                    if downloadState.status == "downloading" {
                        ProgressView(value: downloadState.progress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding()
                    }
                }
            }
        }
    }
}

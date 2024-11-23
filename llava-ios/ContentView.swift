//
//  ContentView.swift
//  llava-ios
//
//  Created by 윤웅상 on 11/2/24.

import SwiftUI
import Foundation
import Combine

struct LlamaModel: Identifiable {
    var id = UUID()
    var name: String
    var filename: String
    var url: String
    var status: String // "downloaded" or "notDownloaded"
}

class DownloadState: ObservableObject {
    @Published var status: String = "notDownloaded" // "downloading", "downloaded"
    @Published var progress: Double = 0.0
    var downloadTask: URLSessionDownloadTask?
    private var progressObserver: AnyCancellable?

    static func getFileURL(filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
    }

    func download(modelName: String, modelUrl: String, filename: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: modelUrl) else { return }
        let fileURL = Self.getFileURL(filename: filename)

        status = "downloading"

        // URLSession을 통한 다운로드 시작
        downloadTask = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            guard error == nil, let tempURL = tempURL else {
                DispatchQueue.main.async {
                    self.status = "notDownloaded"
                    completion(false)
                }
                return
            }
            do {
                try FileManager.default.copyItem(at: tempURL, to: fileURL)
                DispatchQueue.main.async {
                    self.status = "downloaded"
                    self.progress = 1.0
                    completion(true)
                }
            } catch {
                DispatchQueue.main.async {
                    self.status = "notDownloaded"
                    completion(false)
                }
            }
        }

        // Progress Observer 연결
        if let task = downloadTask {
            progressObserver = task.progress.publisher(for: \.fractionCompleted)
                .receive(on: DispatchQueue.main)
                .sink { progress in
                    self.progress = progress
                }
        }

        downloadTask?.resume()
    }
}


class AppState: ObservableObject {
    enum StartupState {
        case startup, loading, started
    }
    
    enum LoadingState {
        case idle, embeddingImage, generatingResponse, reloadingModel
    }
    
    @Published var state: StartupState = .startup
    @Published var loadingState: LoadingState = .idle
    @Published var messages: [ChatMessage] = []
    @Published var downloadedModels: [LlamaModel] = [] // 모델 상태 저장
    @Published var selectedModel: LlamaModel?
    private var llamaContext: LlamaContext?
    @Published var isDownloading: Bool = false
    
    // 기본 제공 모델 정보
    var defaultModels: [LlamaModel] = [
        LlamaModel(
            name: "Model F16",
            filename: "danube-ko-1.8B-base-F16.gguf",
            url: "https://huggingface.co/Hongik-Project-2024/danube-ko-1.8B-base-F16.gguf/resolve/main/danube-ko-1.8B-base-F16.gguf?download=true",
            status: "notDownloaded"
        ),
        LlamaModel(
            name: "Model Q8",
            filename: "danube-ko-1.8B-base-Q8_0.gguf",
            url: "https://huggingface.co/Hongik-Project-2024/danube-ko-1.8B-base-Q8_0.gguf/resolve/main/danube-ko-1.8B-base-Q8_0.gguf?download=true",
            status: "notDownloaded"
        )
    ]
    
    var DEFAULT_SYS_PROMPT: String = "A chat between a curious human and an artificial intelligence assistant. The assistant gives helpful, detailed, and polite answers to the human's questions."
    var DEFAULT_USER_POSTFIX: String = "###Assistant:"
    
    private var conversationLog: String = ""
    public var hasImageEmbedding: Bool = false
    private var lastImageBytes: [UInt8]? = nil
    
    // 초기화 시 다운로드된 모델 불러오기
    func loadModelsFromDisk() {
        downloadedModels = defaultModels.map { model in
            let fileURL = DownloadState.getFileURL(filename: model.filename)
            var updatedModel = model
            updatedModel.status = FileManager.default.fileExists(atPath: fileURL.path) ? "downloaded" : "notDownloaded"
            return updatedModel
        }
    }
    
    // 모델 초기화
    func initializeModel() {
        guard let selectedModel else { return }
        
        let fileURL = DownloadState.getFileURL(filename: selectedModel.filename)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("Model file not found: \(selectedModel.filename)")
            return
        }
        
        guard let mmprojPath = Bundle.main.path(forResource: "mmproj-model-f16", ofType: "gguf") else {
            print("Projection model (mmproj) not found in app bundle.")
            return
        }
        
        print("Projection Model Path: \(mmprojPath)")
        
        do {
            llamaContext = try LlamaContext.create_context(
                path: fileURL.path,
                clipPath: mmprojPath,
                systemPrompt: DEFAULT_SYS_PROMPT,
                userPromptPostfix: DEFAULT_USER_POSTFIX
            )
            print("Model loaded successfully: \(selectedModel.name)")
        } catch {
            print("Failed to initialize model: \(error)")
        }
    }
    
    func ensureContext() {
        if llamaContext == nil {
            print("Loading model...")
            initializeModel()
        }
    }
    
    func addMessage(text: String, image: UIImage?, isUser: Bool) {
        DispatchQueue.main.async {
            self.messages.append(ChatMessage(text: text, image: image, isUser: isUser))
        }
    }
    
    func preInit() async {
        ensureContext()
        guard let llamaContext else { return }
        await llamaContext.completion_system_init()
    }
    
    func complete(text: String, img: UIImage?) async {
        ensureContext()
        guard let llamaContext else { return }
        
        if let img = img {
            DispatchQueue.main.async {
                self.loadingState = .embeddingImage
            }
            lastImageBytes = img.jpegData(compressionQuality: 1.0).map { Array($0) }
            hasImageEmbedding = true
            conversationLog = ""
            await llamaContext.clear()
            await llamaContext.completion_system_init()
        } else if !hasImageEmbedding {
            await llamaContext.clear()
        }
        
        conversationLog += "###Human: \(text) "
        addMessage(text: text, image: img, isUser: true)
        
        DispatchQueue.main.async {
            self.loadingState = .generatingResponse
        }
        
        let imageBytesToUse = img != nil ? lastImageBytes : (hasImageEmbedding ? lastImageBytes : nil)
        await llamaContext.completion_init(text: conversationLog, imageBytes: imageBytesToUse)
        
        var collectedResponse = ""
        
        while await llamaContext.n_cur < llamaContext.n_len {
            var result = await llamaContext.completion_loop()
            
            if let range = result.range(of: "###") {
                let precedingText = result[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                collectedResponse += precedingText
                break
            } else {
                collectedResponse += result
            }
        }
        
        collectedResponse = collectedResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        conversationLog += "###Assistant: \(collectedResponse) "
        addMessage(text: collectedResponse, image: nil, isUser: false)
        
        DispatchQueue.main.async {
            self.loadingState = .idle
        }
    }
    
    func clear() async {
        DispatchQueue.main.async {
            self.loadingState = .reloadingModel
        }
        
        while loadingState == .generatingResponse {
            await Task.yield()
        }
        
        if let llamaContext = llamaContext {
            await llamaContext.clear()
        }
        
        DispatchQueue.main.async {
            self.messages.removeAll()
            self.conversationLog = ""
            self.hasImageEmbedding = false
            self.lastImageBytes = nil
        }
        
        initializeModel()
        
        DispatchQueue.main.async {
            self.loadingState = .idle
        }
    }
}

struct ContentView: View {
    @StateObject var appstate = AppState()
    @State private var showingModelSelection = true
    
    var body: some View {
        Group {
            if showingModelSelection {
                ModelSelectionView(showingModelSelection: $showingModelSelection, appstate: appstate)
            } else {
                InferenceScreenView(appstate: appstate)
            }
        }
        .onAppear {
            appstate.loadModelsFromDisk()
        }
    }
}

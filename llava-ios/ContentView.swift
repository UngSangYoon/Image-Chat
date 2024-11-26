//
//  ContentView.swift
//  llava-ios
//
//  Created by 윤웅상 on 11/2/24.

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
    @Published var downloadedModels: [LlamaModel] = []
    @Published var selectedModel: LlamaModel?
    private var llamaContext: LlamaContext?
    @Published var isDownloading: Bool = false
    @Published var deviceRAMSize: UInt64 = 0 // RAM 용량 저장

    var defaultModels: [LlamaModel] = [
        LlamaModel(
            name: "Model FP16",
            filename: "danube-ko-1.8B-base-F16.gguf",
            url: "https://huggingface.co/Hongik-Project-2024/danube-ko-1.8B-base-F16.gguf/resolve/main/danube-ko-1.8B-base-F16.gguf?download=true",
            status: "notDownloaded"
        ),
        LlamaModel(
            name: "Model Q8 (Lite Version)",
            filename: "danube-ko-1.8B-base-Q8_0.gguf",
            url: "https://huggingface.co/Hongik-Project-2024/danube-ko-1.8B-base-Q8_0.gguf/resolve/main/danube-ko-1.8B-base-Q8_0.gguf?download=true",
            status: "notDownloaded"
        )
    ]

    init() {
        deviceRAMSize = getDeviceRAMSize() // 앱 초기화 시 RAM 용량 확인
    }
    
    var DEFAULT_SYS_PROMPT: String = "A chat between a curious human and an artificial intelligence assistant. The assistant gives helpful, detailed, and polite answers to the human's questions."
    var DEFAULT_USER_POSTFIX: String = "###Assistant:"
    
    private var conversationLog: String = ""
    public var hasImageEmbedding: Bool = false
    private var lastImageBytes: [UInt8]? = nil

    func loadModelsFromDisk() {
        downloadedModels = defaultModels.map { model in
            let fileURL = DownloadState.getFileURL(filename: model.filename)
            var updatedModel = model
            updatedModel.status = FileManager.default.fileExists(atPath: fileURL.path) ? "downloaded" : "notDownloaded"
            return updatedModel
        }
    }

    private func getDeviceRAMSize() -> UInt64 {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        return physicalMemory / (1024 * 1024 * 1024) // GB 단위로 변환
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
        var generationCompleted = false
        var invalidResponseDetected = false // 응답 유효성 확인 플래그
        
        while await llamaContext.n_cur < llamaContext.n_len {
            var result = await llamaContext.completion_loop()
            
            // 응답 검증: 유효하지 않은 경우 중단
            if isInvalidResponse(result) {
                invalidResponseDetected = true
                break
            }
            
            if let range = result.range(of: "###") {
                let precedingText = result[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                collectedResponse += precedingText
                generationCompleted = true
                break
            } else if let range = result.range(of: "</s>") {
                let precedingText = result[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                collectedResponse += precedingText
                generationCompleted = true
                break
            } else {
                collectedResponse += result
            }
        }
        
        if invalidResponseDetected {
            // 유효하지 않은 응답 처리
            DispatchQueue.main.async {
                self.addMessage(
                    text: "모델 생성 한계에 도달했습니다. 아래로 스와이프해 새로고침해 주세요.",
                    image: nil,
                    isUser: false
                )
                self.loadingState = .idle
            }
        } else {
            // 정상적인 응답 처리
            collectedResponse = collectedResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            conversationLog += "###Assistant: \(collectedResponse) "
            addMessage(text: collectedResponse, image: nil, isUser: false)
            
            DispatchQueue.main.async {
                self.loadingState = .idle
            }
        }
    }

    // 유효하지 않은 응답 확인 로직
    private func isInvalidResponse(_ response: String) -> Bool {
        // "<s>" 혹은 <unk>가 포함
        if response.contains("<s>") ||
            response.contains("<unk>") {
            return true
        }
        return false
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

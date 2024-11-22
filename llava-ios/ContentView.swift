//
//  ContentView.swift
//  llava-ios
//
//  Created by 윤웅상 on 11/2/24.

 import Foundation
 import SwiftUI

 class AppState: ObservableObject {
     enum StartupState {
         case Startup
         case Loading
         case Started
     }
     
     enum LoadingState {
         case idle
         case embeddingImage
         case generatingResponse
         case reloadingModel
     }
     
     @Published var state: StartupState = .Startup
     @Published var loadingState: LoadingState = .idle
     @Published var messages: [ChatMessage] = []
     @Published var selectedModelTag: String? = nil
     
     private var llamaContext: LlamaContext?
     public var hasImageEmbedding: Bool = false
     private var lastImageBytes: [UInt8]? = nil
     
     var DEFAULT_SYS_PROMPT: String = "A chat between a curious human and an artificial intelligence assistant. The assistant gives helpful, detailed, and polite answers to the human's questions."
     var DEFAULT_USER_POSTFIX: String = "###Assistant:"
     
     private var conversationLog: String = ""
     
     func ensureContext() {
         if llamaContext == nil {
             print("Loading model...")
             initializeModel()
         }
     }
     
     private func initializeModel() {
         let systemPrompt = DEFAULT_SYS_PROMPT
         let userPostfix = DEFAULT_USER_POSTFIX
         
         if let modelPath = Bundle.main.path(forResource: "danube-ko-1.8B-base-F16", ofType: "gguf"),
            let mmprojPath = Bundle.main.path(forResource: "mmproj-model-f16", ofType: "gguf") {
             print("Model Path: \(modelPath)")
             print("Projection Model Path: \(mmprojPath)")
             do {
                 self.llamaContext = try LlamaContext.create_context(
                    path: modelPath,
                    clipPath: mmprojPath,
                    systemPrompt: systemPrompt,
                    userPromptPostfix: userPostfix
                 )
                 print("Model loaded successfully.")
             } catch {
                 DispatchQueue.main.async {
                     self.addMessage(text: "Model loading failed: \(error.localizedDescription)", image: nil, isUser: false)
                 }
                 print("Error loading model: \(error)")
                 return
             }
         } else {
             print("Model files not found.")
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

         // Wait until response generation completes
         while loadingState == .generatingResponse {
             await Task.yield() // Yield to other tasks and wait
         }

         // Clear existing context
         if let llamaContext = llamaContext {
             await llamaContext.clear()
         }
         
         // Reset messages and conversation log
         DispatchQueue.main.async {
             self.messages.removeAll()
             self.conversationLog = ""
             self.hasImageEmbedding = false
             self.lastImageBytes = nil
         }
         
         // Reinitialize the model
         initializeModel()
         
         DispatchQueue.main.async {
             self.loadingState = .idle
         }
     }
 }

struct ContentView: View {
    @StateObject var appstate = AppState()

    var body: some View {
        InferenceScreenView(appstate: appstate)
            .onAppear {
                appstate.state = .Started
                appstate.ensureContext()
            }
    }
}

//
//  ChatToolbarView.swift
//  MLXChatExample
//
//  Created by İbrahim Çetin on 21.04.2025.
//

import SwiftUI

/// Toolbar view for the chat interface that displays error messages, download progress,
/// generation statistics, and model selection controls.
struct ChatToolbarView: View {
    /// View model containing the chat state and controls
    @Bindable var vm: ChatViewModel
    
    /// Track discovered models to update UI
    @State private var discoveredModels: [LMModel] = []
    
    /// All available models combining preconfigured and discovered
    private var allModels: [LMModel] {
        MLXService.preconfiguredModels + discoveredModels
    }

    var body: some View {
        // Display error message if present
        if let errorMessage = vm.errorMessage {
            ErrorView(errorMessage: errorMessage)
        }

        // Show download progress for model loading
        if let progress = vm.modelDownloadProgress, !progress.isFinished {
            DownloadProgressView(progress: progress)
        }

        // Button to clear chat history, displays generation statistics
        Button {
            vm.clear([.chat, .meta])
        } label: {
            GenerationInfoView(
                tokensPerSecond: vm.tokensPerSecond
            )
        }

        // Model selection picker
        Picker("Model", selection: $vm.selectedModel) {
            // Pre-configured models
            Section {
                ForEach(MLXService.preconfiguredModels) { model in
                    Text(model.displayName)
                        .tag(model)
                }
            } header: {
                Text("Recommended Models")
            }
            
            // Discovered models (if any)
            if !discoveredModels.isEmpty {
                Divider()
                
                Section {
                    ForEach(discoveredModels) { model in
                        Text(model.displayName)
                            .tag(model)
                    }
                } header: {
                    Text("Downloaded Models")
                }
            } else if !ModelDiscoveryService.shared.isDiscovering {
                Divider()
                
                Section {
                    Text("No downloaded models found")
                        .foregroundColor(.secondary)
                        .italic()
                } header: {
                    Text("Downloaded Models")
                } footer: {
                    Text("Place models in ~/Downloads/huggingface/models/{org}/{model}/")
                        .font(.caption)
                }
            }
        }
        .task {
            // Load discovered models when view appears
            await ModelDiscoveryService.shared.discoverModels()
            discoveredModels = ModelDiscoveryService.shared.discoveredModels
        }
    }
}

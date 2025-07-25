//
//  ModelDiscoveryService.swift
//  MLXChatExample
//
//  Created by Claude on 2025-07-25.
//

import Foundation
import MLXLMCommon
import MLXLLM
import MLXVLM

/// Service for discovering MLX models in the Hugging Face cache directory
@MainActor
@Observable
class ModelDiscoveryService {
    /// Shared instance
    static let shared = ModelDiscoveryService()
    
    /// Possible cache directory paths to check
    private var cacheDirectories: [URL] {
        [
            // MLXChatExample download location - this is the primary location
            URL.downloadsDirectory
                .appendingPathComponent("huggingface")
        ]
    }
    
    /// Discovered models from the cache
    private(set) var discoveredModels: [LMModel] = []
    
    /// Whether discovery is in progress
    private(set) var isDiscovering = false
    
    private init() {}
    
    /// Discovers models in the Hugging Face cache
    func discoverModels() async {
        isDiscovering = true
        defer { isDiscovering = false }
        
        var models: [LMModel] = []
        var processedModelIds = Set<String>()
        
        // Check each possible cache directory
        for cacheDir in cacheDirectories {
            do {
                // Skip if directory doesn't exist
                guard FileManager.default.fileExists(atPath: cacheDir.path) else {
                    continue
                }
                
                // Check if we can read the directory
                guard FileManager.default.isReadableFile(atPath: cacheDir.path) else {
                    continue
                }
                
                // Get all contents of the directory
                let contents = try FileManager.default.contentsOfDirectory(
                    at: cacheDir,
                    includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                )
                
                // Filter for model directories
                var modelDirs = contents.filter { url in
                    // Model directories follow pattern: models--{org}--{model-name}
                    url.lastPathComponent.hasPrefix("models--")
                }
                
                // Also check if there's a 'hub' subdirectory
                let hubDir = cacheDir.appendingPathComponent("hub")
                if FileManager.default.fileExists(atPath: hubDir.path) {
                    let hubContents = try FileManager.default.contentsOfDirectory(
                        at: hubDir,
                        includingPropertiesForKeys: nil,
                        options: .skipsHiddenFiles
                    ).filter { url in
                        url.lastPathComponent.hasPrefix("models--")
                    }
                    modelDirs.append(contentsOf: hubContents)
                }
                
                // Also check for 'models' subdirectory (Downloads format)
                let modelsDir = cacheDir.appendingPathComponent("models")
                if FileManager.default.fileExists(atPath: modelsDir.path) {
                    // In Downloads format, we need to go two levels deep: models/{org}/{model}
                    let orgDirs = try FileManager.default.contentsOfDirectory(
                        at: modelsDir,
                        includingPropertiesForKeys: nil,
                        options: .skipsHiddenFiles
                    )
                    
                    for orgDir in orgDirs {
                        if let modelPaths = try? FileManager.default.contentsOfDirectory(
                            at: orgDir,
                            includingPropertiesForKeys: nil,
                            options: .skipsHiddenFiles
                        ) {
                            modelDirs.append(contentsOf: modelPaths)
                        }
                    }
                }
                
                // Process each model directory
                for modelDir in modelDirs {
                    if let model = await processModelDirectory(modelDir),
                       !processedModelIds.contains(model.name) {
                        models.append(model)
                        processedModelIds.insert(model.name)
                    }
                }
                
            } catch {
                // Silently skip inaccessible directories
            }
        }
        
        // Sort models by name
        models.sort { $0.name < $1.name }
        discoveredModels = models
    }
    
    /// Processes a single model directory and returns an LMModel if valid
    private func processModelDirectory(_ modelDir: URL) async -> LMModel? {
        do {
            var modelPath: URL
            
            // Check if this is a hub-style directory with snapshots
            let snapshotsDir = modelDir.appendingPathComponent("snapshots")
            if FileManager.default.fileExists(atPath: snapshotsDir.path) {
                // Get the latest snapshot (usually only one)
                let snapshots = try FileManager.default.contentsOfDirectory(
                    at: snapshotsDir,
                    includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                )
                
                guard let snapshotDir = snapshots.first else {
                    return nil
                }
                modelPath = snapshotDir
            } else {
                // This might be a direct model directory (Downloads format)
                modelPath = modelDir
            }
            
            // Check for required files
            let configPath = modelPath.appendingPathComponent("config.json")
            let modelFilePath = modelPath.appendingPathComponent("model.safetensors")
            let modelIndexPath = modelPath.appendingPathComponent("model.safetensors.index.json")
            let tokenizerPath = modelPath.appendingPathComponent("tokenizer.json")
            
            
            // Model weights can be either single file or sharded
            let hasModelWeights = FileManager.default.fileExists(atPath: modelFilePath.path) ||
                                FileManager.default.fileExists(atPath: modelIndexPath.path)
            
            guard FileManager.default.fileExists(atPath: configPath.path),
                  hasModelWeights,
                  FileManager.default.fileExists(atPath: tokenizerPath.path) else {
                return nil
            }
            
            // Read and parse config.json
            let configData = try Data(contentsOf: configPath)
            let config = try JSONSerialization.jsonObject(with: configData) as? [String: Any]
            
            guard let modelType = config?["model_type"] as? String else {
                return nil
            }
            
            // Check if model type is supported
            let isVLM = config?["vision_config"] != nil
            let typeRegistry = isVLM ? VLMTypeRegistry.shared : LLMTypeRegistry.shared
            
            guard typeRegistry.hasModel(type: modelType) else {
                return nil
            }
            
            // Extract model ID from directory path
            let modelId: String
            let dirName = modelDir.lastPathComponent
            
            if dirName.hasPrefix("models--") {
                // Hub cache format: models--{org}--{model-name}
                let components = dirName.split(separator: "-", maxSplits: 2)
                guard components.count >= 3 else {
                    return nil
                }
                let org = String(components[1])
                let modelName = String(components[2])
                modelId = "\(org)/\(modelName)"
            } else {
                // Downloads format: models/{org}/{model-name}
                // Get the parent directory (org) and current directory (model-name)
                let modelName = modelDir.lastPathComponent
                let orgDir = modelDir.deletingLastPathComponent()
                let org = orgDir.lastPathComponent
                
                // Skip if we're not at the right depth
                guard org != "models" && org != "huggingface" else {
                    return nil
                }
                
                modelId = "\(org)/\(modelName)"
            }
            
            // Create ModelConfiguration with directory path
            let modelConfig = ModelConfiguration(directory: modelPath)
            
            // Create LMModel with discovered source
            let model = LMModel(
                name: modelId,
                configuration: modelConfig,
                type: isVLM ? .vlm : .llm,
                source: .discovered
            )
            
            return model
            
        } catch {
            return nil
        }
    }
}

// Extension to check if a model type is registered
extension ModelTypeRegistry {
    func hasModel(type: String) -> Bool {
        // Check against known model types
        let knownLLMTypes = [
            "llama", "mistral", "phi", "phi3", "phimoe", "gemma", "gemma2", "gemma3",
            "gemma3_text", "gemma3n", "qwen2", "qwen3", "qwen3_moe", "starcoder2",
            "cohere", "openelm", "internlm2", "deepseek_v3", "granite", "mimo",
            "smollm", "lfm2", "bitnet", "exaone", "baichuan-m", "ernie"
        ]
        
        let knownVLMTypes = [
            "paligemma", "qwen2_vl", "qwen2_5_vl", "idefics3", "gemma3", "smolvlm"
        ]
        
        if self is VLMTypeRegistry {
            return knownVLMTypes.contains(type)
        } else {
            return knownLLMTypes.contains(type)
        }
    }
}
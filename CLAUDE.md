# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is MLX Swift Examples - a collection of Swift packages and example applications demonstrating machine learning capabilities using Apple's MLX framework. The repository provides implementations of Large Language Models (LLMs), Vision Language Models (VLMs), Stable Diffusion, and other ML models optimized for Apple Silicon.

## Common Development Commands

### Building
```bash
# Build the entire project
xcodebuild -scheme mlx-libraries-Package build

# Build a specific target
xcodebuild -scheme LLMEval build
xcodebuild -scheme VLMEval build
xcodebuild -scheme MLXChatExample build

# Build for release
xcodebuild -configuration Release -scheme <scheme-name> build
```

### Running Command Line Tools
```bash
# Use the mlx-run wrapper script to run CLI tools
./mlx-run llm-tool --prompt "your prompt here"
./mlx-run mnist-tool
./mlx-run image-tool --prompt "a sunset over mountains"

# Debug mode
./mlx-run --debug llm-tool --help

# List available schemes
./mlx-run --list
```

### Testing
```bash
# Run all tests
xcodebuild test -scheme mlx-libraries-Package

# Run specific test target
xcodebuild test -scheme mlx-libraries-Package -only-testing:MLXLMTests
```

## High-Level Architecture

### Core Libraries

1. **MLXLMCommon** - Foundation library providing common abstractions for language models:
   - Model loading and configuration (`ModelFactory`, `ModelConfiguration`)
   - Evaluation pipeline (`generate()`, `LMInput`, `UserInput`)
   - Tokenization and detokenization
   - KV caching for efficient inference
   - Tool calling support
   - Adapter support (LoRA, DoRA)

2. **MLXLLM** - Large Language Model implementations:
   - Model registry with pre-configured models
   - Implementations: Llama, Qwen, Gemma, Phi, etc.
   - Each model extends base classes from MLXLMCommon

3. **MLXVLM** - Vision Language Model implementations:
   - Extends MLXLMCommon with image processing capabilities
   - Models: PaliGemma, Qwen-VL, SmolVLM, etc.
   - Media processing pipeline for images

4. **StableDiffusion** - Image generation:
   - CLIP text encoding
   - UNet diffusion model
   - VAE decoder
   - Sampling algorithms

5. **MLXEmbedders** - Text embedding models:
   - BERT and NomicBERT implementations
   - Pooling strategies

6. **MLXMNIST** - MNIST dataset and training utilities

### Application Architecture

Applications follow a SwiftUI + MVVM pattern:
- **ViewModels** handle business logic and model interaction
- **Services** abstract MLX model operations
- **Views** provide the UI layer

### Model Loading Flow

1. User specifies a model ID (e.g., "mlx-community/Qwen3-4B-4bit")
2. `ModelFactory` downloads weights and configs from Hugging Face
3. Model is instantiated with the correct architecture
4. Weights are loaded and quantization applied
5. Tokenizer and processor are initialized
6. Everything is wrapped in a `ModelContainer` (actor for thread safety)

### Prompt Templates

Prompt templates are crucial for formatting chat messages correctly for each model:

1. **Template Storage**: Each model's tokenizer includes a chat template in its configuration
2. **Message Flow**:
   - User input → `Chat.Message` objects
   - `MessageGenerator` converts to raw dictionaries
   - `tokenizer.applyChatTemplate()` applies model-specific formatting
   - Returns token IDs ready for inference

3. **Model-Specific Handling**:
   - Some models don't support system messages (`NoSystemMessageGenerator`)
   - VLMs include special tokens for images/videos
   - Tool-calling models format tool specifications

### Key Design Patterns

- **Registry Pattern**: Model types are registered in type registries
- **Factory Pattern**: `ModelFactory` handles complex model instantiation
- **Actor Pattern**: `ModelContainer` provides thread-safe model access
- **Protocol-Oriented**: Heavy use of protocols for extensibility

## Model Implementation Guidelines

When implementing new models:
1. Check existing model implementations for patterns
2. Extend appropriate base classes from MLXLMCommon
3. Register the model type in the appropriate registry
4. Follow existing naming conventions and code style
5. Models should implement `sanitize()` for weight preparation
6. Use MLX operations consistently with existing code

## Model Discovery in MLXChatExample

The MLXChatExample app can dynamically discover models downloaded to specific locations:
- `ModelDiscoveryService` scans `~/Downloads/huggingface/` for MLX models
- Discovered models appear in a "Downloaded Models" section in the UI
- Models must have:
  - `config.json` with a supported `model_type`
  - Model weights (`.safetensors` files)
  - Tokenizer configuration files
- VLM models are detected by presence of `vision_config` in config.json

### Important: Sandbox Limitations

Due to macOS app sandboxing, the app **cannot** access:
- `~/.cache/huggingface/hub/` (standard Hugging Face cache)
- Any directories outside the app's container except Downloads
- Symbolic links pointing outside the sandbox

**Required**: Models must be placed in:
```
~/Downloads/huggingface/models/{org}/{model-name}/
```

Example:
```
~/Downloads/huggingface/models/mlx-community/Llama-3.2-3B-Instruct-4bit/
```

### How to Move Models from Cache

Models in the cache have encoded names like `models--mlx-community--Llama-3.2-3B-Instruct-4bit`.

#### Option 1: Use the provided script
```bash
# Run the script to copy all MLX models
./copy-models-from-cache.sh
```

#### Option 2: Copy manually
```bash
# For a specific model, decode the name:
# models--{org}--{model-name} → {org}/{model-name}

# Example for Llama-3.2-3B-Instruct-4bit:
mkdir -p ~/Downloads/huggingface/models/mlx-community/
cp -LR ~/.cache/huggingface/hub/models--mlx-community--Llama-3.2-3B-Instruct-4bit/snapshots/*/* \
       ~/Downloads/huggingface/models/mlx-community/Llama-3.2-3B-Instruct-4bit/

# The -L flag resolves symlinks during copy
```

#### Understanding the cache structure:
- Cache format: `models--{organization}--{model-name}/snapshots/{hash}/`
- Downloads format: `models/{organization}/{model-name}/`
- The `--` in cache names represents `/` in the model path
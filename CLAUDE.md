# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is MLX Swift Examples - a collection of example applications and command-line tools demonstrating machine learning capabilities using Apple's MLX framework on Apple Silicon.

**Important**: The core LLM/VLM libraries (`MLXLMCommon`, `MLXLLM`, `MLXVLM`, `MLXEmbedders`) have moved to [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm). This repo now focuses on example applications and two libraries: `StableDiffusion` and `MLXMNIST`.

## Common Development Commands

### Building
```bash
# Build the entire project
xcodebuild -scheme mlx-libraries-Package build

# Build a specific application or tool
xcodebuild -scheme LLMEval build
xcodebuild -scheme MLXChatExample build
xcodebuild -scheme llm-tool build

# Build for release
xcodebuild -configuration Release -scheme <scheme-name> build
```

### Running Command Line Tools
```bash
# Use the mlx-run wrapper script (handles DYLD_FRAMEWORK_PATH)
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

### Code Formatting
```bash
# Format all Swift code (uses .swift-format config: 4-space indentation)
swift-format format --in-place --recursive Libraries Tools Applications

# Install pre-commit hook for automatic formatting
pip install pre-commit
pre-commit install
```

## High-Level Architecture

### Libraries (in this repo)

- **StableDiffusion** (`Libraries/StableDiffusion/`) - Image generation with SDXL Turbo and Stable Diffusion
- **MLXMNIST** (`Libraries/MLXMNIST/`) - MNIST dataset loading and training utilities

### External Dependencies (from mlx-swift-lm)

The applications import LLM/VLM functionality from the separate `mlx-swift-lm` package:
- `MLXLMCommon` - Model loading (`ModelFactory`), generation pipeline, tokenization, KV caching
- `MLXLLM` - LLM implementations (Llama, Qwen, Gemma, Phi, etc.)
- `MLXVLM` - Vision language models (PaliGemma, Qwen-VL, SmolVLM, etc.)
- `MLXEmbedders` - Text embedding models (BERT, NomicBERT)

### Applications (`Applications/`)

| App | Platforms | Description |
|-----|-----------|-------------|
| LLMEval | iOS, macOS | Text generation with LLMs |
| VLMEval | iOS, macOS, visionOS | Image analysis with VLMs |
| MLXChatExample | iOS, macOS | Chat interface for LLMs and VLMs |
| MNISTTrainer | iOS, macOS | Train LeNet on MNIST |
| StableDiffusionExample | iOS, macOS | Image generation |
| LoRATrainingExample | macOS | Fine-tune LLMs with LoRA |

### Command Line Tools (`Tools/`)

| Tool | Description |
|------|-------------|
| llm-tool | Text generation, LoRA training commands |
| image-tool | Stable diffusion image generation |
| mnist-tool | MNIST training |
| embedder-tool | Text embeddings |
| ExampleLLM | Simplified LLM API example |

### Application Architecture Pattern

SwiftUI apps follow MVVM:
- `Views/` - SwiftUI views
- `ViewModels/` - Business logic and model interaction
- `Services/` - Abstraction over MLX operations
- `Models/` - Data models

### Model Loading Flow (via mlx-swift-lm)

1. Specify model ID (e.g., "mlx-community/Qwen3-4B-4bit")
2. `ModelFactory` downloads weights and config from Hugging Face
3. Model instantiated with correct architecture, weights loaded
4. Tokenizer and processor initialized
5. Wrapped in `ModelContainer` (actor for thread safety)

## MLXChatExample Model Discovery

The chat app discovers local models from `~/Downloads/huggingface/models/{org}/{model-name}/`.

**Sandbox limitation**: The app cannot access `~/.cache/huggingface/hub/`. Use `./copy-models-from-cache.sh` to copy models to the accessible location.
# MLXChatExample: LLM Context Building Architecture

This document provides an in-depth explanation of how context is built and sent to the LLM in the MLXChatExample application.

## Overview

The MLXChatExample application uses a sophisticated pipeline to transform user messages and conversation history into a format suitable for Large Language Models (LLMs) and Vision-Language Models (VLMs). This process involves multiple layers of abstraction and transformation.

## Context Building Architecture

### 1. Message Structure and Storage

The context starts with the `Message` class (`Models/Message.swift:10-56`):

```swift
@Observable
class Message: Identifiable {
    let id: UUID
    let role: Role              // user/assistant/system
    var content: String         // Text content
    var images: [URL]          // Image attachments
    var videos: [URL]          // Video attachments
    let timestamp: Date
}
```

Messages are stored in `ChatViewModel.messages` array (`ViewModels/ChatViewModel.swift:28`), initialized with a system prompt:
```swift
var messages: [Message] = [
    .system("You are a helpful assistant!")
]
```

### 2. Context Flow Pipeline

When a user sends a message, the following steps occur:

#### Step 1: Message Creation
Location: `ViewModels/ChatViewModel.swift:71`

```swift
// Add user message with any media attachments
messages.append(.user(prompt, images: mediaSelection.images, videos: mediaSelection.videos))
// Add empty assistant message that will be filled during generation
messages.append(.assistant(""))
```

#### Step 2: Message Transformation
Location: `Services/MLXService.swift:93-110`

The app-specific `Message` objects are converted to MLX framework's `Chat.Message` format:

```swift
let chat = messages.map { message in
    let role: Chat.Message.Role =
        switch message.role {
        case .assistant: .assistant
        case .user: .user
        case .system: .system
        }
    
    // Process any attached media for VLM models
    let images: [UserInput.Image] = message.images.map { imageURL in .url(imageURL) }
    let videos: [UserInput.Video] = message.videos.map { videoURL in .url(videoURL) }
    
    return Chat.Message(
        role: role, content: message.content, images: images, videos: videos)
}
```

#### Step 3: UserInput Preparation
Location: `Services/MLXService.swift:113-114`

```swift
let userInput = UserInput(
    chat: chat,  // Full conversation history
    processing: .init(resize: .init(width: 1024, height: 1024))  // Image/video processing options
)
```

#### Step 4: Tokenization and Encoding
Location: `Services/MLXService.swift:118`

```swift
let lmInput = try await context.processor.prepare(input: userInput)
```

This critical step:
- Applies model-specific tokenization
- Formats messages according to the model's chat template
- Encodes text and media into tensors
- Handles special tokens for role boundaries

### 3. Context Components

The complete context sent to the LLM includes:

1. **System Message**: Initial instructions defining assistant behavior
2. **Conversation History**: All previous user/assistant exchanges
3. **Current User Input**: Text prompt + optional media attachments
4. **Model-Specific Formatting**: Applied by the processor based on model type (LLM vs VLM)

### 4. Model-Specific Processing

Different models handle context differently:

#### LLM Models (Text-Only)
Examples: llama3.2, qwen2.5, smolLM, acereason, gemma3n

These models:
- Process text-only context
- Ignore media attachments
- Use text-specific tokenization

#### VLM Models (Vision-Language)
Examples: qwen2.5VL, qwen2VL, smolVLM

These models:
- Process text + visual context
- Generate embeddings for images/videos
- Merge visual and textual representations

The model processor (`MLXService.swift:117-118`) automatically:
- Applies correct chat template formatting
- Handles role markers and turn boundaries
- Manages context window limits
- Prepares multimodal inputs for vision models

### 5. Streaming Response Integration

As the model generates tokens (`Services/MLXService.swift:122-124`):

```swift
return try MLXLMCommon.generate(
    input: lmInput, parameters: parameters, context: context)
```

The response handling:
- Returns `AsyncStream<Generation>` for real-time streaming
- Each chunk appends to the assistant message
- UI updates automatically via `@Observable` properties

```swift
case .chunk(let chunk):
    if let assistantMessage = messages.last {
        assistantMessage.content += chunk
    }
```

### 6. Context Window Management

The framework handles several important aspects:

- **Token Counting**: Ensures context stays within model limits
- **Automatic Truncation**: Truncates if context exceeds limits
- **Efficient Caching**: Caches model states between generations
- **Memory Optimization**: Sets GPU cache limits (`MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)`)

## Data Flow Diagram

```
User Input → ChatViewModel → MLXService → Model Processor → LLM/VLM
    ↓             ↓              ↓              ↓              ↓
  Text +      Messages[]    Transform to   Tokenize &    Generate
  Media                     Chat.Message    Encode       Response
                                                            ↓
UI Update ← ChatViewModel ← AsyncStream<Generation> ← ← ← ← ┘
```

## Key Design Decisions

1. **Separation of Concerns**: Clean separation between UI models (`Message`) and ML framework models (`Chat.Message`)

2. **Observable Architecture**: Using `@Observable` for automatic UI updates during streaming

3. **Unified Interface**: Single `generate()` method handles both LLM and VLM models

4. **Model Caching**: `NSCache` prevents redundant model loading

5. **Flexible Media Handling**: Support for images and videos with automatic resizing

## Performance Considerations

- **GPU Memory Management**: Explicit cache limits prevent OOM errors
- **Streaming Response**: Reduces perceived latency with real-time updates
- **Model Caching**: Avoids expensive reloading operations
- **Lazy Message Updates**: Only the current assistant message is modified during generation

## Summary

The MLXChatExample architecture provides a robust and flexible system for building context for LLMs. It efficiently handles both text-only and multimodal conversations while maintaining clean separation of concerns and supporting real-time streaming capabilities. The design allows for easy extension to new model types while providing a consistent interface for the UI layer.
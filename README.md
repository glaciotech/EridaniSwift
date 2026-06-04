# Examples

This repo includes runnable example apps under `Examples/`.

# Eridani Swift SDK

Eridani Swift SDK helps you build agentic apps in Swift using a KISS approach: let the LLM orchestrate the agentic behavior, and provide the minimal Swift layers needed to make that possible.

Instead of building complex chains, custom workflow graphs, or framework-specific tool adapters, Eridani focuses on the essentials: connecting LLMs to MCP tools, managing exchange history, executing approved tool calls, storing tool results, and feeding those results back to the model so it can decide what to do next.

## Status

Eridani is a new framework. The API is expected to evolve as we iterate based on real-world usage, and this may include breaking changes.

## Why Eridani?

Modern LLMs are capable enough to perform orchestration themselves. Eridani is designed around that assumption.

The SDK provides the Swift-side connectors and control-flow layer that lets the model orchestrate:

- **Expose capabilities through MCP tools**
- **Let the LLM decide when tools are needed**
- **Execute requested tool calls**
- **Allow for approval or deny or requested tool execution**
- **Store user, AI, and tool messages**
- **Return tool results to the model for continued reasoning**
- **Keep app-specific behavior in tools, not in the framework**

The goal is to fill a similar role to heavier agent frameworks, but without unnecessary bloat: simple Swift primitives, MCP-based extensibility, and LLM-led orchestration.

In the case of needing to enforce a specific flow, this can be achieved by creating custom tools which call other tools and return the ultimate outcome to the orchestrating AI.

## Core concepts

- **Exchange managers**: Swift-side control-flow objects that send conversation history to a configured LLM, handle model-requested tool calls, store exchange messages, and continue multi-step exchanges.
- **MCP tool use**: App capabilities are exposed as MCP tools. The LLM decides when a tool is needed, and Eridani handles the Swift-side mechanics of executing and storing the result.
- **Tool approval providers**: The SDK includes primitives for controlling tool execution, with simple approval processes or the ability to build more complex ones.
- **AI services**: Provider-specific connectors for remote LLM services. These create LLMs for OpenAI, Anthropic, xAI, and Inception as well as local LLM services, running on device.
- **Storage services**: Conversation stores preserve user messages, AI responses, tool requests, and tool results for the next LLM request.

## Installation

Add Eridani to your Swift package dependencies.

```swift
.package(url: "https://github.com/glaciotech/EridaniSwift.git", from: "0.1.0")
```

Then add the product to your target:

```swift
.product(name: "EridaniSwift", package: "EridaniSwift")
```

Import the package in your app:

```swift
import EridaniSwift
```

## Quick start

The quickest setup for an agentic app is the same pattern used in the Tool Using Agent example:

- **Load MCP tools into an `MCPToolManager`** (your tools can be local (macOS) or in-process, remote coming soon).
- **Create a tool approval coordinator** (optional, but recommended).
- **Create an LLM** (direct provider key, or via the Eridani proxy).
- **Create a `ToolCallingExchangeManager`** with seed messages and storage.
- **Call `ask(with:)`** and let the model request tools as needed.

```swift
import EridaniSwift
import MCP

// 1) Tool manager + tool loading
let toolManager = MCPToolManager(currentlyEnabled: true)

// For a local/in-process MCP server, you can use an in-memory transport.
// See Examples/ToolUsingAgentExample for a working reference.
// let toolsServer = EridaniToolsServer()
// let clientTransport = try await toolsServer.start()
// try await toolManager.loadDirect(name: "EridaniTools", version: "0.1", clientTransport: clientTransport)

// 2) Tool approval (optional)
let toolApprovalCoordinator = ToolExecutionUserApprovalCoordinator(toolManager: toolManager)

// 3) Storage (in-memory for quickstart)
let storageService = SimpleInMemoryStorageService()

// 4) LLM configuration (direct is easiest for local dev; proxy is typically for production releases)
let openAIKey = UserDefaults.standard.string(forKey: "OPENAI_API_KEY")
let remoteServiceContainer = RemoteLLMServiceContainer(openAIService: OpenAIService(apiKey: openAIKey))
let llm = try RemoteModelManager(with: remoteServiceContainer, toolManager: toolManager).configuredLLM(for: RemoteLLMModel.gpt5Nano)

// 5) Exchange manager + ask
let exchangeManager = ToolCallingExchangeManager(withSeedMessages: [.system(.text("You are a helpful assistant."))], withStorageService: storageService,
                                                withToolManager: toolManager, and: llm, toolExecutionInterceptor: toolApprovalCoordinator)

try await exchangeManager.ask(with: [.text("Summarize https://www.macrumors.com/2026/06/05/siri-in-ios-27-still-labeled-beta-internally/")])
```

## Tool approval

Tool use is a core part of Eridani, but not every requested tool call should automatically run.

Eridani includes approval primitives such as `AlwaysApproveAuthorizer`, `ClosureAuthorizer`, `ToolExecutionUserApprovalCoordinator`, and `ConservativeAnnotationCheckScreener`. Use them to approve, deny, screen, or build user-facing approval flows around model-requested tool calls.

## Examples

Example apps live in `Examples/`.

See [`Examples/README.md`](Examples/README.md) for a quickstart guide (how to run, API keys, and configuration).

Open `Examples/EridaniAppExamples.xcodeproj` and run one of the schemes:

- **ChatAppExample** (`Examples/ChatAppExample`)
- **ToolUsingAgentExample** (`Examples/ToolUsingAgentExample`)

## API key setup

Provider services can be initialized directly with API keys:

```swift
let openAI = OpenAIService(apiKey: openAIKey)
let anthropic = AnthropicService(apiKey: anthropicKey)
let xai = XAiService(apiKey: xaiKey)
let inception = InceptionService(apiKey: inceptionKey)
```

Some services also look in `UserDefaults` when no key is passed:

```swift
UserDefaults.standard.set("<your_openai_api_key>", forKey: "OpenAIAPIKey")
UserDefaults.standard.set("<your_anthropic_api_key>", forKey: "AnthropicAPIKey")
UserDefaults.standard.set("<your_xai_api_key>", forKey: "xaiAPIKey")
UserDefaults.standard.set("<your_inception_api_key>", forKey: "InceptionAPIKey")
```

You can also configure keys as environment variables or launch args in your app’s scheme:

- In Xcode, go to **Product** -> **Scheme** -> **Edit Scheme...**
- **Environment Variables** (recommended): add keys like `OpenAIAPIKey`, `AnthropicAPIKey`, `xaiAPIKey`, `InceptionAPIKey`
- **Arguments Passed On Launch**: add pairs like `-OpenAIAPIKey` / `<your_openai_api_key>`

Do not hardcode API keys in source code. Prefer environment variables, launch arguments, secure storage, or a proxy service.

## Package product

The package product is named `EridaniSwift`.

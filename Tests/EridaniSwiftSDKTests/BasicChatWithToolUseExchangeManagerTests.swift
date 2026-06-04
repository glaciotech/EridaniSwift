//
//  BasicChatWithToolUseExchangeManagerTests.swift
//  EridaniSwiftSDK
//
//  Created by Peter Liddle on 11/25/25.
//

import XCTest
@testable import EridaniSwift
import SwiftyPrompts
import MCPHelpers
import MCP

extension String {
    func normalizingWhitespace() -> String {
        var newString = String()
        var foundWhiteSpace = false
        self.unicodeScalars.forEach({
            if CharacterSet.whitespacesAndNewlines.contains($0) {
                if !foundWhiteSpace {
                    newString.append(" ")
                }
                foundWhiteSpace = true
            }
            else {
                foundWhiteSpace = false
                newString.append("\($0)")
            }
        })
        return newString
    }
}

struct MockValues {
    static let mockCallId = "mock-tool-call-1-id"
    
    static let mockToolCallRequest = MCPToolCallRequest(id: "mock-id", callId: MockValues.mockCallId, toolName: "mock tool", arguments: ["url": .string("https://www.extremetech.com/computing/windows-notepad-receives-table-support")])
    static let mockRetryToolCallRequest = MCPToolCallRequest(id: "mock-id", callId: MockValues.mockCallId + "-retry", toolName: "mock tool", arguments: ["url": .string("https://www.extremetech.com/computing/windows-notepad-receives-table-support"), "scrape": .bool(true)])
    
    static let mockSummaryResponseFromLLM = "SUMMARY FROM TOOL IS: \n \(MockToolManager.mockedSummarizeURLText)" //\(toolCallResponseJson)"
}

struct MockConfiguredLLM: LocalOrRemoteConfiguredLLM {
    var activeModel: EridaniSwiftSDK.LocalLLMModel = .placeholderModel
 
    typealias IC = [SwiftyPrompts.Message]
    
    typealias R = ExchangeOutput<String>
    
    typealias Model = LocalLLMModel
    
    var mockLLMResponseString: String?
    
    func infer(msg: [SwiftyPrompts.Message]) async throws -> SwiftyPrompts.ExchangeOutput<String>? {
        
        let toolMessages = msg.filter({ if case SwiftyPrompts.Message.tool(_) = $0 { return true } else { return false} })
        if let last = toolMessages.last, case let SwiftyPrompts.Message.tool(toolCallResponseJson) = last {
            if let errorMsg = toolCallResponseJson.response?.errorMessage {
                // Try call again if it's a recoverable error
                let toolCall = MockValues.mockRetryToolCallRequest
                return ExchangeOutput(rawText: "mock tool call retry", output: "mock tool call retry", usage: .init(promptTokens: 530, completionTokens: 230, totalTokens: 460), toolCalls: [toolCall])
            }
            else {
                let text = MockValues.mockSummaryResponseFromLLM
                return ExchangeOutput(rawText: text, output: text, usage: .init(promptTokens: 4000, completionTokens: 500, totalTokens: 4500), toolCalls: nil)
            }
        }
        else {
            let toolCall = MockValues.mockToolCallRequest
            let echoContent = msg.map({ $0.content })
            let text = mockLLMResponseString ?? "RESPONSE FROM AI \n ECHOED CONTENT:[\(echoContent)]"
            return ExchangeOutput(rawText: text, output: text, usage: .init(promptTokens: 2530, completionTokens: 2030, totalTokens: 4560), toolCalls: [toolCall])
        }
      
    }
}

struct ErrorMockConfiguredLLM: LocalOrRemoteConfiguredLLM {
    var activeModel: EridaniSwiftSDK.LocalLLMModel = .placeholderModel
    
    typealias IC = [SwiftyPrompts.Message]
    
    typealias R = ExchangeOutput<String>
    
    typealias Model = LocalLLMModel
    
    var mockLLMResponseString: String?
    
    func infer(msg: [SwiftyPrompts.Message]) async throws -> SwiftyPrompts.ExchangeOutput<String>? {
        return .some(.init(rawText: "", output: "", usage: .none))
    }
}

class MockToolManager: ToolManagerProtocol {
    
    static let mockedSummarizeURLResponse = """
        W3sidGV4dCI6IntcbiAgXCJtYWluRmluZGluZ1wiOiBcIk1pY3Jvc29mdCBpcyB0ZXN0aW5nIGEgZmVhdHVyZSB0aGF0IHByZWxvYWRzIEZpbGUgRXhwbG9yZXIgaW4gdGhlIGJhY2tncm91bmQgdG8gaW1wcm92ZSBsYXVuY2ggZWZmaWNpZW5jeS5cIixcbiAgXCJsYXVuY2hTcGVlZEltcGFjdFwiOiBcIlVzZXJzIHdpbGwgZXhwZXJpZW5jZSBmYXN0ZXIgb3BlbmluZyBvZiBGaWxlIEV4cGxvcmVyIGNvbXBhcmVkIHRvIHByZXZpb3VzIHZlcnNpb25zLCB3aXRob3V0IGFueSB2aXN1YWwgY2hhbmdlcy5cIixcbiAgXCJjYXZlYXRzT3JMaW1pdGF0aW9uc1wiOiBcIlVzZXJzIGNhbiBkaXNhYmxlIHRoZSBmZWF0dXJlIHRocm91Z2ggYSBzZXR0aW5nIGluIEZpbGUgRXhwbG9yZXIsIGFsbG93aW5nIHRoZW0gdG8gcmV2ZXJ0IHRvIHN0YW5kYXJkIGJlaGF2aW9yLlwiLFxuICBcImJhY2tncm91bmRQcmVsb2FkaW5nVGVzdFwiOiBcIlRoZSBmZWF0dXJlIHJ1bnMgcHJvY2Vzc2VzIGluIHRoZSBiYWNrZ3JvdW5kIGJlZm9yZSBGaWxlIEV4cGxvcmVyIGxhdW5jaGVzLCByZW1haW5pbmcgaW52aXNpYmxlIHRvIHVzZXJzLCByZXN1bHRpbmcgaW4gcXVpY2tlciBsYXVuY2ggdGltZXMuXCIsXG4gIFwiaW1wbGljYXRpb25zRm9yV2luZG93c1BlcmZvcm1hbmNlXCI6IFwiVGhpcyBjaGFuZ2UgY291bGQgZW5oYW5jZSBvdmVyYWxsIHVzZXIgZXhwZXJpZW5jZSBieSByZWR1Y2luZyB3YWl0IHRpbWVzIGZvciBsYXVuY2hpbmcgRmlsZSBFeHBsb3Jlci5cIlxufSIsInR5cGUiOiJ0ZXh0In1d
        """
    
    static var mockedSummarizeURLText: String {
        let data = Data(base64Encoded: MockToolManager.mockedSummarizeURLResponse)
        let string = try! data!.jsonString()
        return string
    }
    
    typealias ToolResult = String
    
    var currentlyEnabled: Bool = false
    
    var availableTools: [EridaniSwiftSDK.ToolNameComponents : MCP.Tool] = [:]
    
    func handleToolCall(for toolCall: SwiftyPrompts.MCPToolCallRequest) async throws -> [MCP.Tool.Content] {
        let string = Self.mockedSummarizeURLText
        return [.text(string)]
    }
    
    func load(toolConfigs: [MCPHelpers.LocalMCPServerConfig]) async throws {
        fatalError("Not implemented in mock service")
    }
}

class MockRecoverableErrorToolManager: MockToolManager {
    
    override func handleToolCall(for toolCall: SwiftyPrompts.MCPToolCallRequest) async throws -> [MCP.Tool.Content] {
        guard toolCall.callId.hasSuffix("-retry") else {
            throw ToolManagerError.recoverableErrorFromToolCall(toolCall.toolName, "Wrong number of arguments")
        }
        
        return try await super.handleToolCall(for: toolCall)
    }
}

struct MockUnrecoverableErrorToolManager: ToolManagerProtocol {
    
    typealias ToolResult = String
    
    var currentlyEnabled: Bool = false
    
    var availableTools: [EridaniSwiftSDK.ToolNameComponents : MCP.Tool] = [:]
    
    func handleToolCall(for toolCall: SwiftyPrompts.MCPToolCallRequest) async throws -> [MCP.Tool.Content] {
        throw ToolManagerError.unrecoverableErrorFromToolCall(toolCall.toolName, "Insufficent credits to continue")
    }
    
    func load(toolConfigs: [MCPHelpers.LocalMCPServerConfig]) async throws {
        fatalError("Not implemented in mock service")
    }
}

final class BasicChatWithToolUseExchangeManagerTests: XCTestCase {

    var basicChatManager: BasicChatWithToolUseExchangeManager<SimpleInMemoryStorageService>!
    
    override func setUpWithError() throws {
                // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testAsk_succesfullyMakesCallAndStoresResult() async throws {
        
        let inMemoryStore = SimpleInMemoryStorageService()
        
        let mockTallCallLLMResponse = ""
        let basicChatManager = BasicChatWithToolUseExchangeManager(withStorageService: inMemoryStore,
                                                                   withToolManager: MockToolManager(),
                                                                   and: MockConfiguredLLM(mockLLMResponseString: mockTallCallLLMResponse),
                                                                   shouldCallNextStep: { return true })
        
        try await basicChatManager.ask(with: [.text("Summarize https://www.extremetech.com/computing/windows-notepad-receives-table-support")])
        
        let sendableHistory = try await inMemoryStore.sendableHistory()
        print("SENDABLE HISTORY: \n \(sendableHistory)")
        
        // We expect in the memory store
        // 1. Initial ask from the user in this case "Summarize https://www.extremetech.com/computing/windows-notepad-receives-table-support"
        // 2. The tool call JSON object, with the request to call the summary mcp tool from LLM + summary of website returned from the tool
        // 4. AI Response with the AI handing you the summary it recieved back from the tool
        
        
        XCTAssertEqual(sendableHistory[0].author, "user")
        XCTAssertEqual(sendableHistory[0].text, "Summarize https://www.extremetech.com/computing/windows-notepad-receives-table-support")
        
        XCTAssertEqual(sendableHistory[1].author, "tool")
        
        guard case let SwiftyPrompts.Message.tool(tce) = sendableHistory[1] else {
            XCTFail("Stored ToolExchange not expected type")
            return
        }
        
        // Request should match
        XCTAssertEqual(tce.request.prettyJson, MockValues.mockToolCallRequest.prettyJson)
        
        XCTAssertEqual(sendableHistory[2].author, "ai")
        XCTAssertEqual(sendableHistory[2].text.normalizingWhitespace(), MockValues.mockSummaryResponseFromLLM.normalizingWhitespace())
    }
    
    func testAsk_onRecoverableToolCallErrorStoresErrorAndTriesAgain() async throws {
        let inMemoryStore = SimpleInMemoryStorageService()
        
        let mockTallCallLLMResponse = ""
        let basicChatManager = BasicChatWithToolUseExchangeManager(withStorageService: inMemoryStore,
                                                                   withToolManager: MockRecoverableErrorToolManager(),
                                                                   and: MockConfiguredLLM(mockLLMResponseString: mockTallCallLLMResponse),
                                                                   shouldCallNextStep: { return true })

        try await basicChatManager.ask(with: [.text("Summarize https://www.extremetech.com/computing/windows-notepad-receives-table-support")])
        
        let sendableHistory = try await inMemoryStore.sendableHistory()
        print("SENDABLE HISTORY: \n \(sendableHistory)")

        // We expect in the memory store
        // 1. Initial ask from the user in this case "Summarize https://www.extremetech.com/computing/windows-notepad-receives-table-support"
        // 2. The tool call JSON object, with the request to call the summary mcp tool from LLM + recoverable error from the LLM
        // 3. Another attempt to call the tool with different arguments
        // 4. AI Response with the AI handing you the summary it recieved back from the tool
        
        XCTAssertEqual(sendableHistory[0].author, "user")
        XCTAssertEqual(sendableHistory[0].text, "Summarize https://www.extremetech.com/computing/windows-notepad-receives-table-support")
        
        XCTAssertEqual(sendableHistory[1].author, "tool")
        
        guard case let SwiftyPrompts.Message.tool(tce) = sendableHistory[1] else {
            XCTFail("Stored ToolExchange not expected type")
            return
        }
        
        // Request should match
        XCTAssertEqual(tce.request.prettyJson, MockValues.mockToolCallRequest.prettyJson)
        XCTAssertEqual(tce.response?.errorMessage, "Wrong number of arguments")
        
        XCTAssertEqual(sendableHistory[2].author, "ai")
        XCTAssertEqual(sendableHistory[2].text, "mock tool call retry")
        
        guard case let SwiftyPrompts.Message.tool(tce) = sendableHistory[3] else {
            XCTFail("Stored ToolExchange not expected type")
            return
        }
        XCTAssertEqual(tce.request.prettyJson, MockValues.mockRetryToolCallRequest.prettyJson)
        
        XCTAssertEqual(sendableHistory[4].author, "ai")
        XCTAssertEqual(sendableHistory[4].text.normalizingWhitespace(), MockValues.mockSummaryResponseFromLLM.normalizingWhitespace())
    }
    
    func testAsk_onUnrecoverableToolCallError_RethrowsErrorAndStops() async throws {
        
        let inMemoryStore = SimpleInMemoryStorageService()
        
        let mockTallCallLLMResponse = ""
        let basicChatManager = BasicChatWithToolUseExchangeManager(withStorageService: inMemoryStore,
                                                                   withToolManager: MockUnrecoverableErrorToolManager(),
                                                                   and: MockConfiguredLLM(mockLLMResponseString: mockTallCallLLMResponse),
                                                                   shouldCallNextStep: { return true })
        
        do {
            try await basicChatManager.ask(with: [.text("Summarize https://www.extremetech.com/computing/windows-notepad-receives-table-support")])
            XCTFail("Expected an unrecoverable error to be throws")
            
        }
        catch {
            guard case let ToolManagerError.unrecoverableErrorFromToolCall(name, message) = error else {
                XCTFail("Error was thrown but not the right type, error thrown was \(error)")
                return
            }
            
            XCTAssertEqual(name, "mock tool")
            XCTAssertEqual(message, "Insufficent credits to continue")
        }
    }
}

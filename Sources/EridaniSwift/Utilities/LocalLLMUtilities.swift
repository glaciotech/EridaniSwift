//
//  LocalLLMChainManager.swift
//  Ventus
//
//  Created by Peter Liddle on 2/14/24.
//

import Foundation
import Combine
import SwiftyPrompts
import SwiftyPrompts_Local

extension UInt64 {
    static func billion(_ size: Double) -> Self {
        let billion = 1E9
        return UInt64(size * Double(billion))
    }
    
    var asBytes: Self {
        self / 8
    }
}

extension UInt64 {
    
    static let bytesInGb = 1024*1024*1024
    
    static func fromGB(_ gb: Double) -> UInt64 {
        return UInt64(gb * Double(Self.bytesInGb))
    }
}

struct PromptTemplates {
    
    static let llamaTemplate =
                 """
                 <s>[INST] <<SYS>>
                 {system_message}
                 <</SYS>>
                 {user_message}
                 [/INST]
                 
                 """
    
    static let gwenLLMPromptTemplate =
                """
                <|im_start|>system
                {system_message}<|im_end|>
                <|im_start|>user
                {user_message}<|im_end|>
                <|im_start|>assistant
                """
}

enum DownloadResult {
    case running(Double)
    case complete(URL)
}

enum LocalLLMChainError: Error {
    case invalidLocalModel(String)
    case modelNotDownloaded
}

public struct LocalLLMTools {
    public static func cleanMarkdownCharacters(from string: String) -> String {
        let patterns = ["\\*\\*", "-", "_", "\\+", "`", "\\[", "\\]", "\\(", "\\)", "#", "!", "\\|"]

        var cleanedString = string
        for pattern in patterns {
            cleanedString = cleanedString.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }

        return cleanedString
    }
}

public struct Chunker {
    
    public static let characterChunkLimit = 550
    
    public struct ChunkIterator: IteratorProtocol {
        private let chunks: [String]
        private var currentIndex: Int

        public init(userInput: String, chunkSize: Int) {
            self.currentIndex = 0
            self.chunks = Self.splitStringIntoChunks(userInput, chunkLengthLimit: chunkSize)
        }

        public mutating func next() -> String? {
            guard currentIndex < chunks.count else {
                return nil
            }

            let chunk = chunks[currentIndex]
            currentIndex += 1
            
            return chunk
        }

        private static func splitStringIntoChunks(_ string: String, chunkLengthLimit: Int) -> [String] {
            guard string.distance(from: string.startIndex, to: string.endIndex) > chunkLengthLimit else {
                return [string]
            }

            func findChunk(startIndex: String.Index, string: String) -> (String, String.Index) {
                guard startIndex < string.endIndex else {
                    return ("", startIndex)
                }

                let proposedEnd = chunkLengthLimit <= string.distance(from: startIndex, to: string.endIndex) ? string.index(startIndex, offsetBy: chunkLengthLimit) : string.endIndex
                let proposedChunk = string[startIndex..<proposedEnd]

                guard proposedEnd < string.endIndex else {
                    return (String(proposedChunk), proposedEnd)
                }

                let realEnd = proposedChunk.lastIndex(where: { $0.isNewline || $0.isWhitespace }) ?? proposedEnd

                return (String(string[startIndex..<realEnd]), realEnd)
            }

            var chunks: [String] = []
            let endIndex = string.endIndex
            var startIndex = string.startIndex

            while startIndex < endIndex {
                let newChunk = findChunk(startIndex: startIndex, string: string)
                startIndex = string.distance(from: newChunk.1, to: string.endIndex) > 0 ? string.index(after: newChunk.1) : string.endIndex
                chunks.append(newChunk.0)
            }

            return chunks
        }
    }
    
    private let chunkSize: Int

    public init(chunkSize: Int) {
        self.chunkSize = chunkSize
    }
    
    public func makeIterator(userInput: String) -> ChunkIterator {
        return ChunkIterator(userInput: userInput, chunkSize: Self.characterChunkLimit)
    }
}

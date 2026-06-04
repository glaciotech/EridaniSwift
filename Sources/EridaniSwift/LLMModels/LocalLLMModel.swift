//
//  LocalLLMModel.swift
//  EridaniSwift
//
//  Created by Peter Liddle on 8/15/25.
//

import Foundation

public struct LocalLLMModel: AnyLLMModel, RawRepresentable {

    init(embedded: Bool = false, baseModelDir: URL? = nil, company: String, id: String, name: String, repoId: String, sizeInfo: ModelSizeInfo) {
        self.company = company
        self.id = id
        self.name = name
        self.repoId = repoId
        self.sizeInfo = sizeInfo
        self.baseModelDir = baseModelDir
        self.embedded = embedded
    }
    
    public static func == (lhs: LocalLLMModel, rhs: LocalLLMModel) -> Bool {
        return lhs.id == rhs.id && lhs.company == rhs.company && lhs.repoId == rhs.repoId
    }
    
    public struct ModelSizeInfo {
        
        static let empty = Self.init(parameterSizeBillions: 0, weightSizeBits: 0)
        
        public var parameterSizeBillions: UInt64
        public var weightSizeBits: UInt
        public var memoryRequirement: UInt64 {
            return (parameterSizeBillions * UInt64(weightSizeBits)).asBytes
        }
    }
    
    public var embedded = false // Indicates whether the weights are embedded in the app
    public var baseModelDir: URL?
    
    public var company: String
    public var id: String
    public var name: String
    public var repoId: String   // Full path to the repo on huggingface, i.e. "Qwen/Qwen3-0.6b-MLX"

    public var sizeInfo: ModelSizeInfo
    
    public var fullModelName: String {
        return company + "/" + name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension LocalLLMModel: StorableModel {
    public init?(rawValue: String) {
        
        guard let model = LocalLLMModel.allKnown.first(where: { $0.repoId == rawValue }) else {
            return nil
        }
        self = model
    }
    
    public var rawValue: String {
        return repoId
    }
    
    public typealias RawValue = String
}

////https://huggingface.co/mlx-community/
extension LocalLLMModel: HasAvailableModels {
    
    public typealias T = LocalLLMModel
    
    private static let embeddedModelPath: URL = {
        let resourceURL = Bundle.main.url(forResource: "model", withExtension: "safetensors", subdirectory: "models/Qwen3-0.6B-MLX-4bit")
        return resourceURL!.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()  // Delete last 3 to get base model directory
    }()

    // MARK: - Deprecated Qwen2 models, still here incase needed during dev
    // For embedded models the repoPath is just the name of the folder with the model in the resource dir under "models"
//    public static let qwen2_5_0_5b_embedded = LocalLLMModel(embedded: true, baseModelDir: embeddedModelPath, company: "Alibaba", id: "qwen2_5_0_5b", name: "Qwen 2.5 0.5b", repoId: "Qwen2.5-Coder-0.5B-Instruct-4bit", sizeInfo: .init(parameterSizeBillions: .billion(0.5), weightSizeBits: 4))

    
//    public static let qwen2_5_1_5b = LocalLLMModel(company: "Alibaba", id: "qwen2_5_1_5b", name: "Qwen 2.5 1.5b", repoId: "mlx-community/Qwen2.5-Coder-1.5B-Instruct-4bit", sizeInfo: .init(parameterSizeBillions: .billion(1.5), weightSizeBits: 4))
    
//    public static let qwen2_5_7b = LocalLLMModel(company: "Alibaba", id: "qwen2_5_7b", name: "Qwen 2.5 7b", repoId: "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit", sizeInfo: .init(parameterSizeBillions: .billion(7), weightSizeBits: 4))
    
//    public static let qwen2_5_14b = LocalLLMModel(company: "Alibaba", id: "qwen2_5_14b", name: "Qwen 2.5 14b", repoId: "mlx-community/Qwen2.5-Coder-14B-Instruct-4bit", sizeInfo: .init(parameterSizeBillions: .billion(14), weightSizeBits: 4))

    #if DEBUG
// Here for testing
    public static let qwen3_0_6b = LocalLLMModel(company: "Alibaba", id: "qwen3-0_6B-MLX-4bit-not-embedded", name: "Qwen 3 0.6b Not Embedded", repoId: "Qwen/Qwen3-0.6B-MLX-4bit", sizeInfo: .init(parameterSizeBillions: .billion(0.6), weightSizeBits: 4))
    #endif
    
    //MARK: - Qwen 3 models
    public static let qwen3_0_6b_embedded = LocalLLMModel(embedded: true, baseModelDir: embeddedModelPath, company: "Alibaba", id: "qwen3-0_6B-MLX-4bit", name: "Qwen 3 0.6b", repoId: "Qwen3-0.6B-MLX-4bit", sizeInfo: .init(parameterSizeBillions: .billion(0.5), weightSizeBits: 4))
    
    public static let qwen3_1_7b = LocalLLMModel(company: "Alibaba", id: "Qwen3-1.7B-MLX-4bit", name: "Qwen 3 1.7b", repoId: "Qwen/Qwen3-1.7B-MLX-4bit", sizeInfo: .init(parameterSizeBillions: .billion(1.7), weightSizeBits: 4))
    
    public static let qwen3_4b = LocalLLMModel(company: "Alibaba", id: "Qwen3-4B-MLX-4bit", name: "Qwen 3 4b", repoId: "Qwen/Qwen3-4B-MLX-4bit", sizeInfo: .init(parameterSizeBillions: .billion(4), weightSizeBits: 4))
    
    public static let qwen3_8b = LocalLLMModel(company: "Alibaba", id: "Qwen3-8B-MLX-4bit", name: "Qwen 3 8b", repoId: "Qwen/Qwen3-8B-MLX-4bit", sizeInfo: .init(parameterSizeBillions: .billion(8), weightSizeBits: 4))
    
    public static let qwen3_14b = LocalLLMModel(company: "Alibaba", id: "Qwen3-14B-MLX-4bit", name: "Qwen 3 14b", repoId: "Qwen/Qwen3-14B-MLX-4bit", sizeInfo: .init(parameterSizeBillions: .billion(14), weightSizeBits: 4))
    
    public static let qwen3_32b = LocalLLMModel(company: "Alibaba", id: "Qwen3-32B-MLX-4bit", name: "Qwen 3 32b", repoId: "Qwen/Qwen3-32B-MLX-4bit", sizeInfo: .init(parameterSizeBillions: .billion(32), weightSizeBits: 4))
    

    
    
    // Not allowed under license models
    // LocalLLMModels.qwen2_5_3b : LocalModelInfo(company: "Alibaba", id: .qwen2_5_3b, name: "Qwen 2.5 3b", repoId: "Qwen2.5-Coder-3B-Instruct-4bit", parameterSizeBillions: .billion(3), weightSizeBits: 4),  - Removed due to license restriction
    // LocalLLMModels.qwen2_5_72b : LocalModelInfo(company: "Alibaba", id: .qwen2_5_14b, name: "Qwen 2.5 14b", repoId: "Qwen2.5-72B-Instruct-4bit",parameterSizeBillions: .billion(72), weightSizeBits: 4), - Removed due to license restriction
    
    // Add code later to load additional models from UserDefaults, maybe for local models
    public static let allKnown = {
        var known = [
            qwen3_0_6b_embedded,
//            qwen2_5_1_5b,
//            qwen2_5_7b,
//            qwen2_5_14b,
            qwen3_1_7b,
            qwen3_4b,
            qwen3_8b,
            qwen3_14b,
            qwen3_32b
        ]
        
#if DEBUG
        return known + [qwen3_0_6b]
#else
        return known
#endif
    }()
}

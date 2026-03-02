//
//  FoundationModelsClient.swift
//  CCZUHelper
//
//  Created by Assistant on 2025/12/17.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// A minimal wrapper to unify text generation across build targets.
/// - On iOS 26+ with FoundationModels available, replace the internals to call the real SDK.
/// - On other targets, it returns a simple truncated placeholder so the app continues to work.
public struct TextGenerationRequest {
    public let prompt: String
    public let maxTokens: Int
    public init(prompt: String, maxTokens: Int = 200) {
        self.prompt = prompt
        self.maxTokens = maxTokens
    }
}

public struct TextGenerationResponse {
    public let text: String
}

public actor TextGenerator {
    /// Create a default text generator. Replace internals with the real FM initialization when available.
    public static func makeDefault() async throws -> TextGenerator {
        return TextGenerator()
    }

    /// Generate text from a request.
    public func generate(_ request: TextGenerationRequest) async throws -> TextGenerationResponse {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            // Use Apple's on-device LanguageModelSession with instructions for summarization
            let instructions = """
            请用中文为上面的帖子生成一段不超过 120 字的简洁摘要，突出关键信息与结论。
            """
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: request.prompt)

            // 尝试从调试描述中解析 transcriptEntries，提取 (Response) 之后的文本
            let rawDescription = String(describing: response)
            let extracted: String = {
                // 期望格式示例：
                // "transcriptEntries: ArraySlice([(Response) 这里是模型输出 ... ])"
                // 1) 找到 "(Response)" 的起始位置
                guard let range = rawDescription.range(of: "(Response)") else { return "" }
                let afterResponse = rawDescription[range.upperBound...]

                // 2) 去除可能的右侧 "]" 或 ")" 或空白
                var text = String(afterResponse)
                // 截断到第一个 "]"（如果存在）
                if let endIdx = text.firstIndex(of: "]") {
                    text = String(text[..<endIdx])
                }
                // 再次清理多余空白和换行
                text = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

                return text
            }()

            let final = extracted.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !final.isEmpty {
                return TextGenerationResponse(text: final)
            } else {
                // 无法解析出内容时，返回简短提示，避免返回原始 prompt
                return TextGenerationResponse(text: "（未能从响应中提取摘要内容）")
            }
        } else {
            // Fallback for older OS versions
            let trimmed = request.prompt.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let snippet = String(trimmed.prefix(max(80, min(200, request.maxTokens))))
            return TextGenerationResponse(text: snippet)
        }
        #else
        // Fallback when FoundationModels is not present at build time
        let trimmed = request.prompt.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let snippet = String(trimmed.prefix(max(80, min(200, request.maxTokens))))
        return TextGenerationResponse(text: snippet)
        #endif
    }
}

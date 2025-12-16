//
//  ImageUploadService.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/16.
//

import Foundation

// MARK: - 自定义错误类型
enum UploadError: Error, LocalizedError {
    case invalidFileURL
    case cannotReadFile
    case apiFailure(message: String)
    case invalidResponse
    case decodingError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidFileURL:
            return "Invalid file URL"
        case .cannotReadFile:
            return "Cannot read file at the specified path"
        case .apiFailure(let message):
            return "API Error: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - API 响应模型
struct ImageUploadResponse: Codable {
    let status: Int
    let message: String
    let img_url: String?
    
    enum CodingKeys: String, CodingKey {
        case status
        case message
        case img_url
    }
}

// MARK: - 图片上传服务
struct ImageUploadService {
    private static let apiURL = "https://img.scdn.io/api/v1.php"
    private static let timeout: TimeInterval = 30
    
    /// 上传图片到图床
    /// - Parameters:
    ///   - fileURL: 本地图片文件的 URL
    ///   - password: 可选的密码保护
    /// - Returns: 上传后的图片 URL
    /// - Throws: UploadError 如果上传失败
    static func uploadImage(at fileURL: URL, withPassword password: String? = nil) async throws -> String {
        // 1. 验证文件 URL
        guard fileURL.isFileURL else {
            throw UploadError.invalidFileURL
        }
        
        // 2. 读取文件数据
        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileURL)
        } catch {
            throw UploadError.cannotReadFile
        }
        guard fileData.count > 0 else {
            throw UploadError.cannotReadFile
        }
        
        // 动态判断 mimeType
        let mimeType = mimeTypeForFileExtension(fileURL.pathExtension)
        
        // 3. 构造 multipart/form-data 请求体
        let boundary = UUID().uuidString
        var body = Data()
        
        // 添加输出格式参数
        appendFormField(name: "outputFormatString", value: "webp", to: &body, boundary: boundary)
        
        // 添加密码相关参数
        if let password = password {
            appendFormField(name: "password_enabled", value: "true", to: &body, boundary: boundary)
            appendFormField(name: "image_password", value: password, to: &body, boundary: boundary)
        }
        
        // 添加图片文件
        appendFileField(
            name: "image",
            filename: fileURL.lastPathComponent,
            mimeType: mimeType,
            data: fileData,
            to: &body,
            boundary: boundary
        )
        
        // 添加结束边界
        body.append("--\(boundary)--\r\n".data(using: .utf8) ?? Data())
        
        // 4. 创建 URLRequest
        var request = URLRequest(url: URL(string: Self.apiURL)!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Self.timeout
        request.httpBody = body
        
        // 5. 发送请求
        let (responseData, urlResponse): (Data, URLResponse)
        do {
            (responseData, urlResponse) = try await URLSession.shared.data(for: request)
        } catch {
            throw UploadError.networkError(error)
        }
        
        // 6. 验证 HTTP 响应
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            // 打印详细响应内容，便于调试
            if let debugString = String(data: responseData, encoding: .utf8) {
                print("[ImageUploadService] 400/非200响应内容: \(debugString)")
            }
            let errorMessage = "HTTP \(httpResponse.statusCode)"
            throw UploadError.apiFailure(message: errorMessage)
        }
        
        // 7. 兼容多种返回格式：JSON 或纯字符串
        if responseData.isEmpty {
            throw UploadError.invalidResponse
        }
        let decoder = JSONDecoder()
        // 1. 尝试 status/img_url 格式
        if let json = try? decoder.decode(ImageUploadResponse.self, from: responseData) {
            guard json.status == 200 else {
                throw UploadError.apiFailure(message: json.message)
            }
            guard let imageURL = json.img_url, !imageURL.isEmpty else {
                throw UploadError.invalidResponse
            }
            return imageURL
        }
        // 2. 尝试 success/url 格式
        struct AltImageUploadResponse: Decodable {
            let success: Bool
            let url: String?
            let message: String?
        }
        if let altJson = try? decoder.decode(AltImageUploadResponse.self, from: responseData) {
            guard altJson.success, let imageURL = altJson.url, !imageURL.isEmpty else {
                throw UploadError.apiFailure(message: altJson.message ?? "上传失败")
            }
            return imageURL
        }
        // 3. 直接返回图片 URL 字符串
        if let urlString = String(data: responseData, encoding: .utf8), urlString.starts(with: "http") {
            return urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        throw UploadError.decodingError("未知响应格式")
    }
    
    /// 根据文件扩展名判断 mimeType
    private static func mimeTypeForFileExtension(_ ext: String) -> String {
        let lower = ext.lowercased()
        switch lower {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "heic": return "image/heic"
        default: return "application/octet-stream"
        }
    }
    
    /// 辅助函数：添加普通表单字段
    private static func appendFormField(
        name: String,
        value: String,
        to body: inout Data,
        boundary: String
    ) {
        body.append("--\(boundary)\r\n".data(using: .utf8) ?? Data())
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8) ?? Data())
        body.append("\(value)\r\n".data(using: .utf8) ?? Data())
    }
    
    /// 辅助函数：添加文件表单字段
    private static func appendFileField(
        name: String,
        filename: String,
        mimeType: String,
        data: Data,
        to body: inout Data,
        boundary: String
    ) {
        body.append("--\(boundary)\r\n".data(using: .utf8) ?? Data())
        body.append(
            "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8) ?? Data()
        )
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8) ?? Data())
        body.append(data)
        body.append("\r\n".data(using: .utf8) ?? Data())
    }
}

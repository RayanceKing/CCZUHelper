//
//  TeahouseUserService.swift
//  CCZUHelper
//
//  Created by Copilot on 2026/3/2.
//

import Foundation
import Supabase

/// 茶楼用户服务 - 负责用户资料和图片上传
@MainActor
final class TeahouseUserService {
    
    // MARK: - User Profile
    
    /// 从服务器获取用户资料
    func fetchProfile(userId: String) async throws -> Profile {
        let profiles: [Profile] = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .execute()
            .value
        guard let profile = profiles.first else {
            throw NSError(domain: "TeahouseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])
        }
        return profile
    }
    
    /// 更新用户资料，只允许修改昵称和头像
    func upsertProfile(
        userId: String,
        nickname: String,
        avatarImageData: Data?
    ) async throws -> Profile {
        var avatarUrl: String?
        if let data = avatarImageData {
            avatarUrl = try await uploadAvatarImage(userId: userId, imageData: data)
        }
        
        struct ProfileUpdate: Encodable {
            let username: String
            let avatarUrl: String?
            
            enum CodingKeys: String, CodingKey {
                case username
                case avatarUrl = "avatar_url"
            }
        }
        
        let update = ProfileUpdate(
            username: nickname,
            avatarUrl: avatarUrl
        )
        
        let profiles: [Profile] = try await supabase
            .from("profiles")
            .update(update)
            .eq("id", value: userId)
            .select()
            .execute()
            .value
        
        guard let profile = profiles.first else {
            throw NSError(domain: "TeahouseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to update profile"])
        }
        
        return profile
    }
    
    // MARK: - Image Upload
    
    /// 上传帖子图片到图床，并返回外链 URL 列表
    func uploadPostImages(imageFileURLs: [URL]) async throws -> [String] {
        var urls: [String] = []
        for fileURL in imageFileURLs {
            let url = try await ImageUploadService.uploadImage(at: fileURL)
            urls.append(url)
        }
        return urls
    }

    /// 上传头像并更新 profiles.avatar_url 字段
    func uploadAvatarImage(userId: String, imageData: Data) async throws -> String {
        // 将图片数据保存到临时文件
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        
        try imageData.write(to: tempURL)
        
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        // 使用自定义图床上传
        let publicURL = try await ImageUploadService.uploadImage(at: tempURL)
        
        if publicURL.isEmpty {
            throw AppError.urlGenerationFailed
        }

        try await supabase
            .from("profiles")
            .update(["avatar_url": publicURL])
            .eq("id", value: userId)
            .execute()

        return publicURL
    }
}

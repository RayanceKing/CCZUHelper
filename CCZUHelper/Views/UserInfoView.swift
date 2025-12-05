//
//  UserInfoView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/5.
//

import SwiftUI
import CCZUKit

#if canImport(UIKit)
import UIKit
#endif

/// 用户基本信息视图
struct UserInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    
    @State private var userInfo: UserBasicInfo?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showImagePicker = false
    #if canImport(UIKit)
    @State private var selectedImageForCrop: UIImage?
    #else
    @State private var selectedImageForCrop: NSImage?
    #endif
    @State private var showCropView = false
    
    /// 根据当前用户生成特定的缓存键
    private var cacheKey: String {
        "cachedUserInfo_\(settings.username ?? "anonymous")"
    }
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("loading".localized)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("user_info.loading_failed".localized, systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("retry".localized) {
                        Task {
                            await refreshData()
                        }
                    }
                }
            } else if let info = userInfo {
                ScrollView {
                    VStack(spacing: 20) {
                        // 头像和姓名
                        VStack(spacing: 12) {
                            // 头像（可点击更换）
                            #if os(macOS)
                            Group {
                                if let avatarPath = settings.userAvatarPath {
                                    if let nsImage = NSImage(contentsOfFile: avatarPath) {
                                        Image(nsImage: nsImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.blue, lineWidth: 2)
                                            )
                                    } else {
                                        defaultAvatarImage
                                    }
                                } else {
                                    defaultAvatarImage
                                }
                            }
                            #else
                            Button(action: {
                                showImagePicker = true
                            }) {
                                if let avatarPath = settings.userAvatarPath {
                                    #if canImport(UIKit)
                                    if let uiImage = UIImage(contentsOfFile: avatarPath) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.blue, lineWidth: 2)
                                            )
                                    } else {
                                        defaultAvatarImage
                                    }
                                    #endif
                                } else {
                                    defaultAvatarImage
                                }
                            }
                            #endif
                            
                            Text(info.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(info.studentNumber)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 20)
                        
                        // 基本信息卡片
                        InfoCard(title: "user_info.basic".localized) {
                            VStack(spacing: 12) {
                                UserInfoRow(label: "user_info.gender".localized, value: info.gender)
                                Divider()
                                UserInfoRow(label: "user_info.birthday".localized, value: info.birthday)
                                Divider()
                                UserInfoRow(label: "user_info.phone".localized, value: info.phone)
                            }
                        }
                        
                        // 学籍信息卡片
                        InfoCard(title: "user_info.academic".localized) {
                            VStack(spacing: 12) {
                                UserInfoRow(label: "user_info.college".localized, value: info.collegeName)
                                Divider()
                                UserInfoRow(label: "user_info.major".localized, value: info.major)
                                Divider()
                                UserInfoRow(label: "user_info.class".localized, value: info.className)
                                Divider()
                                UserInfoRow(label: "user_info.grade".localized, value: "\(info.grade)")
                                Divider()
                                UserInfoRow(label: "user_info.study_length".localized, value: "\(info.studyLength)年")
                                Divider()
                                UserInfoRow(label: "user_info.status".localized, value: info.studentStatus)
                            }
                        }
                        
                        // 校区信息卡片
                        InfoCard(title: "user_info.campus_info".localized) {
                            VStack(spacing: 12) {
                                UserInfoRow(label: "user_info.campus".localized, value: info.campus)
                                Divider()
                                UserInfoRow(label: "user_info.dormitory".localized, value: info.dormitoryNumber)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("user_info.title".localized)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            // 1. 优先从缓存加载
            if let cachedInfo = loadFromCache() {
                userInfo = cachedInfo
            } else {
                isLoading = true
            }
            
            // 2. 异步刷新数据
            Task {
                await refreshData()
            }
        }
        #if os(iOS) || os(visionOS)
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(completion: { url in
                if let url = url,
                   let imageData = try? Data(contentsOf: url) {
                    // 删除临时文件
                    try? FileManager.default.removeItem(at: url)
                    
                    // 显示裁剪界面
                    #if canImport(UIKit)
                    if let uiImage = UIImage(data: imageData) {
                        selectedImageForCrop = uiImage
                        showCropView = true
                    }
                    #else
                    if let nsImage = NSImage(data: imageData) {
                        selectedImageForCrop = nsImage
                        showCropView = true
                    }
                    #endif
                }
            }, filePrefix: "avatar_temp")
        }
        #endif
        #if os(iOS) || os(visionOS)
        .fullScreenCover(isPresented: $showCropView) {
            if let image = selectedImageForCrop {
                ImageCropView(image: image) { croppedImage in
                    if let croppedImage = croppedImage {
                        // 保存裁剪后的图片
                        saveAvatar(croppedImage)
                    }
                    selectedImageForCrop = nil
                }
            }
        }
        #endif
    }
    
    /// 刷新数据
    private func refreshData() async {
        guard settings.isLoggedIn, let username = settings.username else {
            await MainActor.run {
                if userInfo == nil {
                    errorMessage = settings.isLoggedIn ? "user_info.error.missing_username".localized : "user_info.error.please_login".localized
                }
                isLoading = false
            }
            return
        }
        
        do {
            guard let password = KeychainHelper.read(service: "com.cczu.helper", account: username) else {
                throw NetworkError.credentialsMissing
            }
            
            let client = DefaultHTTPClient(username: username, password: password)
            _ = try await client.ssoUniversalLogin()
            
            let app = JwqywxApplication(client: client)
            _ = try await app.login()
            
            // 获取学生基本信息
            let infoResponse = try await app.getStudentBasicInfo()
            
            await MainActor.run {
                if let basicInfo = infoResponse.message.first {
                    let newInfo = UserBasicInfo(
                        name: basicInfo.name,
                        studentNumber: basicInfo.studentNumber,
                        gender: basicInfo.gender,
                        birthday: basicInfo.birthday,
                        collegeName: basicInfo.collegeName,
                        major: basicInfo.major,
                        className: basicInfo.className,
                        grade: basicInfo.grade,
                        studyLength: basicInfo.studyLength,
                        studentStatus: basicInfo.studentStatus,
                        campus: basicInfo.campus,
                        phone: basicInfo.phone,
                        dormitoryNumber: basicInfo.dormitoryNumber,
                        majorCode: basicInfo.majorCode,
                        classCode: basicInfo.classCode,
                        studentId: basicInfo.studentId,
                        genderCode: basicInfo.genderCode
                    )
                    userInfo = newInfo
                    saveToCache(info: newInfo)
                } else if userInfo == nil {
                    errorMessage = "user_info.error.no_data".localized
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                if userInfo == nil {
                    // 触发错误震动
                    triggerErrorHaptic()
                    
                    let errorDesc = error.localizedDescription.lowercased()
                    if errorDesc.contains("authentication") || errorDesc.contains("认证") || errorDesc.contains("401") {
                        errorMessage = "error.authentication_failed".localized
                    } else if errorDesc.contains("network") || errorDesc.contains("网络") {
                        errorMessage = "error.network_failed".localized
                    } else {
                        errorMessage = "user_info.error.fetch_failed".localized(with: error.localizedDescription)
                    }
                }
                isLoading = false
            }
        }
    }
    
    // MARK: - 缓存管理
    
    /// 保存到缓存
    private func saveToCache(info: UserBasicInfo) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(info) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
    
    /// 从缓存加载
    private func loadFromCache() -> UserBasicInfo? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode(UserBasicInfo.self, from: data) else {
            return nil
        }
        return decoded
    }
    
    // MARK: - 头像管理
    
    /// 触发错误震动反馈
    private func triggerErrorHaptic() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        #endif
    }
    
    private var defaultAvatarImage: some View {
        Image(systemName: "person.crop.circle.fill")
            .font(.system(size: 80))
            .foregroundStyle(.blue)
    }
    
    /// 保存裁剪后的头像
    #if canImport(UIKit)
    private func saveAvatar(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return
        }
        saveAvatarData(imageData)
    }
    #else
    private func saveAvatar(_ image: NSImage) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let imageData = bitmap.representation(using: .jpeg, properties: [:]) else {
            return
        }
        saveAvatarData(imageData)
    }
    #endif
    
    private func saveAvatarData(_ imageData: Data) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970)
        let destinationURL = documentsPath.appendingPathComponent("avatar_\(timestamp).jpg")
        
        // 删除旧的头像文件
        let fileManager = FileManager.default
        if let existingFiles = try? fileManager.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil) {
            for file in existingFiles where file.lastPathComponent.hasPrefix("avatar_") && !file.lastPathComponent.contains("synced") {
                try? fileManager.removeItem(at: file)
            }
        }
        
        // 保存新头像
        do {
            try imageData.write(to: destinationURL)
            settings.userAvatarPath = destinationURL.path
            
            // 同步到iCloud
            AccountSyncManager.syncAvatarToiCloud(avatarPath: destinationURL.path)
        } catch {
            print("保存头像失败: \(error)")
        }
    }
}

/// 信息卡片容器
struct InfoCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
            
            content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                #if os(macOS)
                .fill(Color(nsColor: .controlBackgroundColor))
                #else
                .fill(Color(.systemBackground))
                #endif
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

/// 信息行（已存在于其他文件，这里为了独立性重复定义）
struct UserInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    NavigationStack {
        UserInfoView()
            .environment(AppSettings())
    }
}

//
//  TeahouseUserProfileView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/14.
//

import SwiftUI
internal import Auth
#if canImport(UIKit)
import UIKit
private typealias ProfileImageType = UIImage
#else
import AppKit
private typealias ProfileImageType = NSImage
#endif

/// 茶楼用户档案视图 - 仅在已登录时显示
struct TeahouseUserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var teahouseService = TeahouseService()
    @State private var serverProfile: Profile?
    @State private var isLoadingProfile = false
    @State private var loadProfileError: String?
    
    @State private var showLogoutConfirmation = false
    @State private var showCustomizeProfile = false
    @State private var nicknameInput: String = ""
    @State private var selectedAvatarImage: ProfileImageType?
    @State private var isSavingProfile = false
    
    private var userEmail: String {
        authViewModel.session?.user.email ?? "未知"
    }
    
    private var userId: String? {
        authViewModel.session?.user.id.uuidString
    }

    private var displayName: String {
        serverProfile?.username ?? settings.userDisplayName ?? settings.username ?? "用户"
    }

    private var avatarView: some View {
        Group {
            #if canImport(UIKit)
            // 优先使用本地缓存
            if let avatarPath = settings.userAvatarPath,
               let uiImage = UIImage(contentsOfFile: avatarPath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .onAppear {
                        // 后台静默刷新服务器头像
                        silentlyRefreshAvatar()
                    }
            } else if let urlString = serverProfile?.avatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.blue)
                    @unknown default:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.blue)
                    }
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.blue)
                    .onAppear {
                        // 没有本地缓存时也尝试刷新
                        silentlyRefreshAvatar()
                    }
            }
            #else
            // macOS: 优先使用本地缓存
            if let avatarPath = settings.userAvatarPath,
               let data = try? Data(contentsOf: URL(fileURLWithPath: avatarPath)),
               let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .onAppear {
                        // 后台静默刷新服务器头像
                        silentlyRefreshAvatar()
                    }
            } else if let urlString = serverProfile?.avatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.blue)
                    @unknown default:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.blue)
                    }
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.blue)
                    .onAppear {
                        // 没有本地缓存时也尝试刷新
                        silentlyRefreshAvatar()
                    }
            }
            #endif
        }
        .frame(width: 50, height: 50)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 用户信息部分（仅展示，不可点击）
                Section {
                    HStack(spacing: 12) {
                        avatarView
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName)
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text(userEmail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Button {
                        nicknameInput = displayName
                        selectedAvatarImage = nil
                        showCustomizeProfile = true
                    } label: {
                        Text("自定义个人资料")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.borderless)

                    // 刷新资料按钮移除：避免频繁刷新
                } header: {
                    Text("账户信息")
                }
                
                // 我的内容
                Section {
                    if let userId = userId {
                        NavigationLink {
                            UserPostsListView(type: .myPosts, userId: userId)
                                .environmentObject(authViewModel)
                        } label: {
                            Label("我发的帖", systemImage: "square.and.pencil")
                        }
                        
                        NavigationLink {
                            UserPostsListView(type: .likedPosts, userId: userId)
                                .environmentObject(authViewModel)
                        } label: {
                            Label("我点赞的", systemImage: "heart")
                        }
                        
                        NavigationLink {
                            UserPostsListView(type: .commentedPosts, userId: userId)
                                .environmentObject(authViewModel)
                        } label: {
                            Label("我评论的", systemImage: "bubble.right")
                        }
                    }
                } header: {
                    Text("我的内容")
                }
                
                // 退出登录按钮
                Section {
                    Button(role: .destructive, action: {
                        showLogoutConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            Text("退出登录")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("茶楼账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .task {
                // 首次出现时拉取一次服务器资料（如果尚未加载）
                if serverProfile == nil, let uid = userId {
                    isLoadingProfile = true
                    loadProfileError = nil
                    Task {
                        do {
                            let prof = try await teahouseService.fetchProfile(userId: uid)
                            await MainActor.run {
                                serverProfile = prof
                                settings.userDisplayName = prof.username
                                isLoadingProfile = false
                            }
                        } catch {
                            await MainActor.run {
                                loadProfileError = error.localizedDescription
                                isLoadingProfile = false
                            }
                        }
                    }
                }
            }
            .alert("退出登录", isPresented: $showLogoutConfirmation) {
                Button("取消", role: .cancel) { }
                Button("退出登录", role: .destructive) {
                    Task {
                        await authViewModel.signOut()
                        dismiss()
                    }
                }
            } message: {
                Text("确定要退出登录吗？")
            }
        }
        .sheet(isPresented: $showCustomizeProfile) {
            CustomizeProfileSheet(
                avatarUrl: serverProfile?.avatarUrl,
                isPresented: $showCustomizeProfile,
                nickname: $nicknameInput,
                selectedAvatarImage: $selectedAvatarImage,
                onSave: saveCustomProfile
            )
            .environment(settings)
            .environmentObject(authViewModel)
        }
        .alert("错误", isPresented: .constant(loadProfileError != nil)) {
            Button("确定", role: .cancel) { loadProfileError = nil }
        } message: {
            Text(loadProfileError ?? "")
        }
    }

    // MARK: - Actions
    
    /// 后台静默刷新服务器头像到本地缓存
    private func silentlyRefreshAvatar() {
        guard let profile = serverProfile, let avatarUrlString = profile.avatarUrl else { return }
        
        // 避免重复刷新
        guard !isLoadingProfile else { return }
        
        Task {
            do {
                guard let url = URL(string: avatarUrlString) else { return }
                let (data, _) = try await URLSession.shared.data(from: url)
                
                // 保存到本地
                await MainActor.run {
                    if let savedPath = saveAvatarToLocal(data: data) {
                        settings.userAvatarPath = savedPath
                        print("✅ 头像后台刷新成功: \(savedPath)")
                    }
                }
            } catch {
                print("⚠️ 后台刷新头像失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveCustomProfile(nickname: String, _ image: ProfileImageType?) {
        guard let userId = authViewModel.session?.user.id.uuidString else { return }
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let basic = loadCachedUserBasicInfo()
        let realName = basic?.name ?? settings.userDisplayName ?? userEmail
        let studentId = basic?.studentNumber ?? ""
        let className = basic?.className ?? ""
        let grade = basic?.grade ?? 0
        let collegeName = basic?.collegeName ?? ""
        
        var avatarData: Data?
        if let img = image {
            #if canImport(UIKit)
            avatarData = img.jpegData(compressionQuality: 0.9)
            #else
            if let tiff = img.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff) {
                avatarData = bitmap.representation(using: .jpeg, properties: [:])
            }
            #endif
        } else if let path = settings.userAvatarPath {
            avatarData = try? Data(contentsOf: URL(fileURLWithPath: path))
        }
        
        isSavingProfile = true
        Task {
            do {
                _ = try await teahouseService.upsertProfile(
                    userId: userId,
                    nickname: trimmedNickname.isEmpty ? userEmail : trimmedNickname,
                    realName: realName,
                    studentId: studentId,
                    className: className,
                    grade: grade,
                    collegeName: collegeName,
                    avatarImageData: avatarData
                )
                await MainActor.run {
                    settings.userDisplayName = trimmedNickname.isEmpty ? userEmail : trimmedNickname
                    if let data = avatarData, let savedPath = saveAvatarToLocal(data: data) {
                        settings.userAvatarPath = savedPath
                    }
                    isSavingProfile = false
                    showCustomizeProfile = false
                }
            } catch {
                await MainActor.run {
                    isSavingProfile = false
                }
                print("❌ 保存个人资料失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadCachedUserBasicInfo() -> UserBasicInfo? {
        let key = "cachedUserInfo_\(settings.username ?? "anonymous")"
        if let data = UserDefaults.standard.data(forKey: key) {
            return try? JSONDecoder().decode(UserBasicInfo.self, from: data)
        }
        return nil
    }
    
    private func saveAvatarToLocal(data: Data) -> String? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970)
        let destinationURL = documentsPath.appendingPathComponent("avatar_custom_\(timestamp).jpg")
        do {
            let fm = FileManager.default
            if let files = try? fm.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil) {
                for f in files where f.lastPathComponent.hasPrefix("avatar_custom_") {
                    try? fm.removeItem(at: f)
                }
            }
            try data.write(to: destinationURL)
            return destinationURL.path
        } catch {
            print("保存头像到本地失败: \(error.localizedDescription)")
            return nil
        }
    }
}

#Preview {
    TeahouseUserProfileView()
    .environmentObject(AuthViewModel())
    .environment(AppSettings())
}

// MARK: - Customize Profile Sheet

private struct CustomizeProfileSheet: View {
    let avatarUrl: String?
    @Environment(AppSettings.self) private var settings
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Binding var isPresented: Bool
    @Binding var nickname: String
    @Binding var selectedAvatarImage: ProfileImageType?
    var onSave: (String, ProfileImageType?) -> Void
    
    @State private var showImagePicker = false
    @State private var pickerFileURL: URL?
    @State private var isSaving: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("自定义你的个人资料")
                          .font(.title.bold())
                          .frame(maxWidth: .infinity)
                          .multilineTextAlignment(.center)
                          .padding(.top, 8)
                    
                    VStack(spacing: 16) {
                        Button {
                            showImagePicker = true
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                avatarContent
                                    .frame(width: 180, height: 180)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle().stroke(Color.primary.opacity(0.08), lineWidth: 2)
                                    )
                                
                                Circle()
                                    .fill(Color(.systemBackground))
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        Image(systemName: "pencil")
                                            .foregroundColor(.blue)
                                            .font(.title2)
                                    )
                                    .offset(x: 12, y: 12)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("昵称")
                                .fontWeight(.semibold)
                            TextField("输入昵称", text: $nickname)
                                .padding(12)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                        }
                        
                        Text("你的头像和昵称对所有人可见。")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("完成") {
                            isSaving = true
                            onSave(nickname.trimmingCharacters(in: .whitespacesAndNewlines), selectedAvatarImage)
                        }
                        .disabled(isSaving)
                    }
                }
            }
        }
        .onChange(of: isPresented) { _, newValue in
            if newValue == false {
                isSaving = false
            }
        }
        .sheet(isPresented: $showImagePicker, onDismiss: loadSelectedImage) {
            ImagePickerView(completion: { url in
                pickerFileURL = url
                showImagePicker = false
            }, filePrefix: "avatar_custom")
        }
    }
    
    private var avatarContent: some View {
        Group {
            if let urlString = avatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholderAvatar
                    @unknown default:
                        placeholderAvatar
                    }
                }
            } else if let image = selectedAvatarImage {
                #if canImport(UIKit)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                #else
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                #endif
            } else {
                placeholderAvatar
            }
        }
    }

    private var placeholderAvatar: some View {
        Image(systemName: "person.fill")
            .resizable()
            .scaledToFit()
            .padding(36)
            .foregroundStyle(.secondary)
    }
    
    private func loadSelectedImage() {
        guard let url = pickerFileURL else { return }
        if let data = try? Data(contentsOf: url) {
            #if canImport(UIKit)
            if let img = UIImage(data: data) {
                selectedAvatarImage = img
            }
            #else
            if let img = NSImage(data: data) {
                selectedAvatarImage = img
            }
            #endif
        }
        try? FileManager.default.removeItem(at: url)
    }
}


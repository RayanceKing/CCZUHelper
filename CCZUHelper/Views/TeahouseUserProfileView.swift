//
//  TeahouseUserProfileView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/14.
//

import SwiftUI
internal import Auth
#if canImport(StoreKit)
import StoreKit
#endif
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
    @State private var showDeleteAccountWarning = false
    @State private var showDeleteAccountView = false
    @State private var showHideBannerPurchasePrompt = false
    @State private var showIAPErrorAlert = false
    @State private var iapErrorMessage = ""
    @State private var isPurchasingHideBanner = false
    @State private var isRestoringPurchases = false
    
    private var userEmail: String {
        authViewModel.session?.user.email ?? "common.unknown".localized
    }
    
    private var userId: String? {
        authViewModel.session?.user.id.uuidString
    }

    private var displayName: String {
        serverProfile?.username ?? settings.userDisplayName ?? settings.username ?? "common.user".localized
    }

    private var avatarView: some View {
        Group {
            if let avatarPath = settings.userAvatarPath,
               let image = loadLocalAvatar(at: avatarPath) {
                image
                    .resizable()
                    .scaledToFill()
                    .onAppear {
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
                        defaultAvatarImage
                    @unknown default:
                        defaultAvatarImage
                    }
                }
            } else {
                defaultAvatarImage
                    .onAppear {
                        silentlyRefreshAvatar()
                    }
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }

    private var defaultAvatarImage: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.blue)
    }

    private func loadLocalAvatar(at path: String) -> Image? {
        #if canImport(UIKit)
        if let uiImage = UIImage(contentsOfFile: path) {
            return Image(uiImage: uiImage)
        }
        #else
        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let nsImage = NSImage(data: data) {
            return Image(nsImage: nsImage)
        }
        #endif
        return nil
    }
    
    private func mainList(@Bindable settings: AppSettings) -> some View {
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
                    Text("profile.customize".localized)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.borderless)

                // 刷新资料按钮移除：避免频繁刷新
            } header: {
                Text("account.info".localized)
            }
            
            // 我的内容
            Section {
                if let userId = userId {
                    NavigationLink {
                        UserPostsListView(type: .myPosts, userId: userId)
                            .environmentObject(authViewModel)
                    } label: {
                        Label("post.my_posts".localized, systemImage: "square.and.pencil")
                    }
                    
                    NavigationLink {
                        UserPostsListView(type: .likedPosts, userId: userId)
                            .environmentObject(authViewModel)
                    } label: {
                        Label("post.my_likes".localized, systemImage: "heart")
                    }
                    
                    NavigationLink {
                        UserPostsListView(type: .commentedPosts, userId: userId)
                            .environmentObject(authViewModel)
                    } label: {
                        Label("post.my_comments".localized, systemImage: "bubble.right")
                    }
                    
                    // 管理员功能：待处理举报
                    if settings.isPrivilege {
                        NavigationLink {
                            ReportedPostsView()
                                .environmentObject(authViewModel)
                        } label: {
                            Label("report.pending".localized, systemImage: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                        }
                    }
                }
            } header: {
                Text("post.my_content".localized)
            }
            
            // 特权功能
            Section {
                TeahouseBannerPurchaseControls(
                    hideBannerBinding: hideBannerBinding,
                    isPurchasing: isPurchasingHideBanner,
                    isRestoring: isRestoringPurchases,
                    onRestore: {
                        Task { await restoreBannerPurchase() }
                    }
                )
            } header: {
                Text("privileges.title".localized)
            }
            
            // 退出登录按钮
            Section {
                Button(role: .destructive, action: {
                    showLogoutConfirmation = true
                }) {
                    HStack {
                        Spacer()
                        Text("logout.confirm_title".localized)
                        Spacer()
                    }
                }
            }
            
            // 注销账户按钮
            Section {
                Button(role: .destructive, action: {
                    showDeleteAccountWarning = true
                }) {
                    HStack {
                        Spacer()
                        Text("account.delete_account".localized)
                        Spacer()
                    }
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            mainList(settings: settings)
                .navigationTitle("teahouse.account".localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("common.done".localized) {
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
                                    settings.isPrivilege = prof.isPrivilege ?? false
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
                .alert("logout.confirm_title".localized, isPresented: $showLogoutConfirmation) {
                    Button("common.cancel".localized, role: .cancel) { }
                    Button("logout.confirm_title".localized, role: .destructive) {
                        Task {
                            await authViewModel.signOut()
                            dismiss()
                        }
                    }
                } message: {
                    Text("logout.confirm_message".localized)
                }
                .alert("account.delete_account".localized, isPresented: $showDeleteAccountWarning) {
                    Button("common.cancel".localized, role: .cancel) { }
                    Button("account.delete_account".localized, role: .destructive) {
                        showDeleteAccountView = true
                    }
                } message: {
                    Text("account.delete_confirm_message".localized)
                }
                .alert("teahouse.hide_banners.purchase_title".localized, isPresented: $showHideBannerPurchasePrompt) {
                    Button("common.cancel".localized, role: .cancel) { }
                    Button("teahouse.hide_banners.purchase_button".localized) {
                        Task { await purchaseBannerHideFeature() }
                    }
                } message: {
                    Text("teahouse.hide_banners.purchase_message".localized)
                }
                .alert("teahouse.hide_banners.purchase_failed_title".localized, isPresented: $showIAPErrorAlert) {
                    Button("common.ok".localized, role: .cancel) { }
                } message: {
                    Text(iapErrorMessage)
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
        .sheet(isPresented: $showDeleteAccountView) {
            TeahouseDeleteAccountView()
                .environment(settings)
        }
        .alert("common.error".localized, isPresented: .constant(loadProfileError != nil)) {
            Button("common.ok".localized, role: .cancel) { loadProfileError = nil }
        } message: {
            Text(loadProfileError ?? "")
        }
        .onChange(of: authViewModel.session) { _, newSession in
            if newSession == nil {
                // 账户已被删除或退出登录，关闭个人资料页面
                dismiss()
            }
        }
        .task {
            await refreshBannerPurchaseStatus()
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

    private var hideBannerBinding: Binding<Bool> {
        Binding(
            get: { settings.hideTeahouseBanners },
            set: { newValue in
                if newValue {
                    if settings.hasTeahouseBannerHidePurchase {
                        settings.hideTeahouseBanners = true
                    } else {
                        settings.hideTeahouseBanners = false
                        showHideBannerPurchasePrompt = true
                    }
                } else {
                    settings.hideTeahouseBanners = false
                }
            }
        )
    }

    @MainActor
    private func setIAPError(_ message: String) {
        iapErrorMessage = message
        showIAPErrorAlert = true
    }

    private func refreshBannerPurchaseStatus() async {
#if canImport(StoreKit)
        do {
            let entitlement = try await hasBannerHideEntitlement()
            await MainActor.run {
                settings.hasTeahouseBannerHidePurchase = entitlement
                if !entitlement {
                    settings.hideTeahouseBanners = false
                }
            }
        } catch {
            await MainActor.run {
                settings.hasTeahouseBannerHidePurchase = false
                settings.hideTeahouseBanners = false
            }
        }
#endif
    }

    private func purchaseBannerHideFeature() async {
#if canImport(StoreKit)
        await MainActor.run { isPurchasingHideBanner = true }
        defer {
            Task { @MainActor in
                isPurchasingHideBanner = false
            }
        }

        do {
            let products = try await Product.products(for: InAppPurchaseProducts.teahouseHideBannersCandidates)
            let product = InAppPurchaseProducts.teahouseHideBannersCandidates
                .compactMap { id in products.first(where: { $0.id == id }) }
                .first
            guard let product else {
                await MainActor.run {
                    setIAPError("teahouse.hide_banners.product_unavailable".localized)
                }
                return
            }

            #if os(visionOS)
            await MainActor.run {
                setIAPError("teahouse.hide_banners.purchase_failed".localized)
            }
            return
            #else
            let result = try await product.purchase()
            #endif
            #if !os(visionOS)
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    await MainActor.run {
                        setIAPError("teahouse.hide_banners.purchase_verification_failed".localized)
                    }
                    return
                }
                await transaction.finish()
                await MainActor.run {
                    settings.hasTeahouseBannerHidePurchase = true
                    settings.hideTeahouseBanners = true
                }
            case .pending:
                await MainActor.run {
                    setIAPError("teahouse.hide_banners.purchase_pending".localized)
                }
            case .userCancelled:
                break
            @unknown default:
                await MainActor.run {
                    setIAPError("teahouse.hide_banners.purchase_failed".localized)
                }
            }
            #endif
        } catch {
            await MainActor.run {
                setIAPError(error.localizedDescription)
            }
        }
#endif
    }

    private func restoreBannerPurchase() async {
#if canImport(StoreKit)
        await MainActor.run { isRestoringPurchases = true }
        defer {
            Task { @MainActor in
                isRestoringPurchases = false
            }
        }

        do {
            try await AppStore.sync()
            let entitlement = try await hasBannerHideEntitlement()
            await MainActor.run {
                settings.hasTeahouseBannerHidePurchase = entitlement
                settings.hideTeahouseBanners = entitlement && settings.hideTeahouseBanners
            }
            if !entitlement {
                await MainActor.run {
                    setIAPError("teahouse.hide_banners.restore_not_found".localized)
                }
            }
        } catch {
            await MainActor.run {
                setIAPError("teahouse.hide_banners.restore_failed".localized)
            }
        }
#endif
    }

#if canImport(StoreKit)
    private func hasBannerHideEntitlement() async throws -> Bool {
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            guard InAppPurchaseProducts.teahouseHideBannersCandidates.contains(transaction.productID) else { continue }
            if transaction.revocationDate != nil { continue }
            if let expirationDate = transaction.expirationDate, expirationDate < Date() { continue }
            return true
        }
        return false
    }
#endif
    
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
            print("Failed to save avatar locally: \(error.localizedDescription)")
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
                    Text("profile.customize_prompt".localized)
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
                            Text("profile.nickname".localized)
                                .fontWeight(.semibold)
                            TextField("profile.enter_nickname".localized, text: $nickname)
                                .padding(12)
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                        }
                        
                        Text("profile.visibility_notice".localized)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
                .padding(24)
            }
            .scrollContentBackground(.hidden)
            .background(
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close".localized) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("common.done".localized) {
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

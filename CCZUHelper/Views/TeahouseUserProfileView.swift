//
//  TeahouseUserProfileView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/14.
//

import SwiftUI
internal import Auth

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
    @State private var showMembershipPurchaseSheet = false
    @State private var showIAPErrorAlert = false
    @State private var iapErrorMessage = ""
    @State private var isPurchasingHideBanner = false
    @State private var isRestoringPurchases = false
    
    private var userId: String? {
        authViewModel.session?.user.id.uuidString
    }
    
    var body: some View {
        viewContent
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
            .sheet(isPresented: $showMembershipPurchaseSheet) {
                MembershipPurchaseView()
                    .environment(settings)
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
            .alert("purchase.failed_title".localized, isPresented: $showIAPErrorAlert) {
                Button("common.ok".localized, role: .cancel) { }
            } message: {
                Text(iapErrorMessage)
            }
            .alert("common.error".localized, isPresented: .constant(loadProfileError != nil)) {
                Button("common.ok".localized, role: .cancel) { loadProfileError = nil }
            } message: {
                Text(loadProfileError ?? "")
            }
            .onChange(of: authViewModel.session) { _, newSession in
                if newSession == nil {
                    dismiss()
                }
            }
            .task {
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
            .task {
                await refreshBannerPurchaseStatus()
            }
    }
    
    @ViewBuilder
    private var viewContent: some View {
        #if os(macOS)
        navigationStackMac
        #else
        navigationStackIOS
        #endif
    }
    
    #if os(macOS)
    @ViewBuilder
    private var navigationStackMac: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TeahouseProfileHeader(
                    serverProfile: serverProfile,
                    isLoadingProfile: isLoadingProfile,
                    showCustomizeProfile: $showCustomizeProfile
                )
                .frame(height: 150)
                .padding()
                
                TeahouseProfileContentMac(
                    userId: userId,
                    serverProfile: serverProfile,
                    hideBannerBinding: hideBannerBinding,
                    isPurchasingHideBanner: isPurchasingHideBanner,
                    isRestoringPurchases: isRestoringPurchases,
                    onShowPurchase: { showMembershipPurchaseSheet = true },
                    onRestorePurchase: { Task { await restoreBannerPurchase() } },
                    showLogoutConfirmation: $showLogoutConfirmation,
                    showDeleteAccountWarning: $showDeleteAccountWarning
                )
            }
            .navigationTitle("teahouse.account".localized)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
            .frame(minWidth: 760, minHeight: 620)
        }
    }
    #endif
    
    #if !os(macOS)
    @ViewBuilder
    private var navigationStackIOS: some View {
        NavigationStack {
            List {
                TeahouseProfileHeader(
                    serverProfile: serverProfile,
                    isLoadingProfile: isLoadingProfile,
                    showCustomizeProfile: $showCustomizeProfile
                )
                
                Section(header: Text("post.my_content".localized)) {
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
                }
                
                Section(header: Text("privileges.title".localized)) {
                    TeahouseBannerPurchaseControls(
                        hideBannerBinding: hideBannerBinding,
                        isPurchasing: isPurchasingHideBanner,
                        isRestoring: isRestoringPurchases,
                        onPurchase: { showMembershipPurchaseSheet = true },
                        onRestore: { Task { await restoreBannerPurchase() } }
                    )
                }
                
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
            .navigationTitle("teahouse.account".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
    #endif

    // MARK: - Private Methods
    
    private var hideBannerBinding: Binding<Bool> {
        Binding(
            get: { settings.hideTeahouseBanners },
            set: { newValue in
                if newValue {
                    if settings.hasPurchase {
                        settings.hideTeahouseBanners = true
                    } else {
                        settings.hideTeahouseBanners = false
                        showMembershipPurchaseSheet = true
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
        let manager = MembershipManager.shared
        let hasEntitlement = await manager.checkProEntitlement()
        await MainActor.run {
            settings.hasPurchase = hasEntitlement
            if !hasEntitlement {
                settings.hideTeahouseBanners = false
                settings.enableICloudDataSync = false
                settings.enableLiveActivity = false
            }
        }
    }

    private func restoreBannerPurchase() async {
        await MainActor.run { isRestoringPurchases = true }
        defer {
            Task { @MainActor in
                isRestoringPurchases = false
            }
        }

        let manager = MembershipManager.shared
        let result = await manager.restorePurchases()
        
        await MainActor.run {
            switch result {
            case .success:
                settings.hasPurchase = true
                settings.hideTeahouseBanners = true
            case .cancelled:
                break
            case .error(let message):
                setIAPError(message)
            }
        }
    }
    
    private func saveCustomProfile(nickname: String, _ image: ProfileImageType?) {
        guard let userId = authViewModel.session?.user.id.uuidString else { return }
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let basic = loadCachedUserBasicInfo()
        let userEmail = authViewModel.session?.user.email ?? "common.unknown".localized
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

//
//  RegistrationProfileSetupView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/15.
//  用于注册流程第二步的个人资料设置视图

import SwiftUI
import Supabase
#if canImport(UIKit)
import UIKit
private typealias RegistrationImage = UIImage
#else
import AppKit
private typealias RegistrationImage = NSImage
#endif

struct RegistrationProfileSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var teahouseService = TeahouseService()
    
    let email: String
    let password: String
    var onCancel: () -> Void
    var onFinished: () -> Void
    
    @State private var nickname: String = ""
    @State private var selectedAvatarImage: RegistrationImage?
    @State private var showImagePicker = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var pickerFileURL: URL?
    
    // 从教务系统获取的信息
    @State private var isLoadingUserInfo = false
    @State private var realName: String = ""
    @State private var studentId: String = ""
    @State private var className: String = ""
    @State private var collegeName: String = ""
    @State private var grade: Int = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("registration.profile.title".localized)
                        .font(.title.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                        .disabled(isSaving)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("registration.profile.nickname".localized)
                                .fontWeight(.semibold)
                            TextField("registration.profile.nickname_placeholder".localized, text: $nickname)
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                                .disabled(isSaving)
                        }
                        
                        Text("registration.profile.avatar_hint".localized)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    
                    VStack(spacing: 12) {
                        if #available(iOS 26.0, *) {
                            Button(action: { Task { await completeRegistration() } }) {
                                HStack {
                                    if isSaving {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                    } else {
                                        Text("registration.profile.complete".localized)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .disabled(nickname.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                            .buttonStyle(.glassProminent)
                            .controlSize(.large)
                            .buttonBorderShape(.automatic)
                        } else {
                            Button(action: { Task { await completeRegistration() } }) {
                                HStack {
                                    if isSaving {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                    } else {
                                        Text("registration.profile.complete".localized)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .disabled(nickname.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .buttonBorderShape(.automatic)
                        }
                        
                        Button(action: onCancel) {
                            Text("cancel".localized)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .buttonBorderShape(.automatic)
                        .disabled(isSaving)
                        
                        Text("registration.profile.hint".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("error".localized, isPresented: .constant(errorMessage != nil)) {
                Button("ok".localized, role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .sheet(isPresented: $showImagePicker, onDismiss: loadSelectedImage) {
                ImagePickerView(completion: { url in
                    pickerFileURL = url
                    showImagePicker = false
                }, filePrefix: "avatar_register")
            }
            .onAppear {
                loadUserInfo()
            }
        }
    }
    
    private var avatarContent: some View {
        Group {
            if let image = selectedAvatarImage {
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

    private func loadUserInfo() {
        isLoadingUserInfo = true
        let key = "user_basic_info_cache"
        if let data = UserDefaults.standard.data(forKey: key),
           let userBasicInfo = try? JSONDecoder().decode(UserBasicInfo.self, from: data) {
            realName = userBasicInfo.name
            studentId = userBasicInfo.studentNumber
            className = userBasicInfo.className
            collegeName = userBasicInfo.collegeName
            if studentId.count >= 1,
               let firstChar = studentId.first,
               let year = Int(String(firstChar)) {
                grade = 2000 + year
            }
        }
        isLoadingUserInfo = false
    }

    private func completeRegistration() async {
        guard !nickname.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "registration.profile.error.nickname_empty".localized
            return
        }
        
        guard !realName.isEmpty else {
            errorMessage = "registration.profile.error.no_edu_info".localized
            return
        }
        
        if isSaving { return }
        isSaving = true

        do {
            if authViewModel.session == nil {
                await authViewModel.signUp(email: email, password: password)
                if let error = authViewModel.errorMessage {
                    await MainActor.run {
                        isSaving = false
                        errorMessage = error
                    }
                    return
                }
            }
            guard let userId = authViewModel.session?.user.id.uuidString else {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "registration.profile.error.no_user_id".localized
                }
                return
            }
            var avatarUrl: String? = nil
            if let image = selectedAvatarImage {
                avatarUrl = try await uploadAvatar(image, userId: userId)
            }
            struct ProfileInsert: Codable {
                let id: String
                let realName: String
                let studentId: String
                let className: String
                let collegeName: String
                let grade: Int
                let username: String
                let avatarUrl: String?

                enum CodingKeys: String, CodingKey {
                    case id
                    case realName = "real_name"
                    case studentId = "student_id"
                    case className = "class_name"
                    case collegeName = "college_name"
                    case grade
                    case username
                    case avatarUrl = "avatar_url"
                }
            }
            let profile = ProfileInsert(
                id: userId,
                realName: realName,
                studentId: studentId,
                className: className,
                collegeName: collegeName,
                grade: grade,
                username: nickname,
                avatarUrl: avatarUrl
            )
            try await supabase
                .from("profiles")
                .upsert(profile)
                .execute()
            await MainActor.run {
                settings.userDisplayName = nickname
                settings.username = nickname
                if let avatarUrl = avatarUrl {
                    settings.userAvatarPath = avatarUrl
                }
                isSaving = false
                dismiss()
                onFinished()
            }
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func uploadAvatar(_ image: RegistrationImage, userId: String) async throws -> String? {
        #if canImport(UIKit)
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ImageError", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法压缩图片"])
        }
        #else
        guard let imageData = image.tiffRepresentation?.base64EncodedData() else {
            throw NSError(domain: "ImageError", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法压缩图片"])
        }
        #endif
        
        let fileName = "\(userId)_avatar.jpg"
        let path = "avatars/\(fileName)"
        
        try await supabase.storage
            .from("avatars")
            .upload(path, data: imageData, options: FileOptions(upsert: true))
        
        return try supabase.storage.from("avatars").getPublicURL(path: path).absoluteString
    }
}

//#Preview {
//    RegistrationProfileSetupView(
//        onSubmit: { },
//        onCancel: { }
//    )
//    .environment(AppSettings.shared)
//    .environmentObject(AuthViewModel())
//}

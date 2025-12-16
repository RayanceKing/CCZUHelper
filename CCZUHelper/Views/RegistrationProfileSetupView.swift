//
//  RegistrationProfileSetupView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/15.
//  用于注册流程第二步的个人资料设置视图

import SwiftUI
import Supabase
#if canImport(CCZUKit)
import CCZUKit
#endif
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
                            #if os(visionOS)
                            .buttonStyle(.borderedProminent)
                            #else
                            .buttonStyle(.glassProminent)
                            #endif
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
        Task {
            if let cached = loadCachedUserInfo() {
                await MainActor.run {
                    applyUserInfo(cached)
                    isLoadingUserInfo = false
                }
                return
            }

#if canImport(CCZUKit)
            do {
                let fetched = try await fetchUserInfoFromTeachingSystem()
                await MainActor.run {
                    applyUserInfo(fetched)
                    cacheUserInfo(fetched)
                    isLoadingUserInfo = false
                }
            } catch {
                await MainActor.run {
                    isLoadingUserInfo = false
                    errorMessage = "registration.profile.error.no_edu_info".localized
                }
            }
#else
            await MainActor.run {
                isLoadingUserInfo = false
                errorMessage = "registration.profile.error.no_edu_info".localized
            }
#endif
        }
    }

    @MainActor
    private func applyUserInfo(_ userBasicInfo: UserBasicInfo) {
        realName = userBasicInfo.name
        studentId = userBasicInfo.studentNumber
        className = userBasicInfo.className
        collegeName = userBasicInfo.collegeName
        grade = userBasicInfo.grade
    }

    private func loadCachedUserInfo() -> UserBasicInfo? {
        let cacheKey = "cachedUserInfo_\(settings.username ?? "anonymous")"
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let info = try? JSONDecoder().decode(UserBasicInfo.self, from: data) {
            return info
        }
        if let data = UserDefaults.standard.data(forKey: "user_basic_info_cache"),
           let info = try? JSONDecoder().decode(UserBasicInfo.self, from: data) {
            return info
        }
        return nil
    }

    private func cacheUserInfo(_ info: UserBasicInfo) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(info) {
            UserDefaults.standard.set(data, forKey: "cachedUserInfo_\(settings.username ?? "anonymous")")
            UserDefaults.standard.set(data, forKey: "user_basic_info_cache")
        }
    }

#if canImport(CCZUKit)
    private func fetchUserInfoFromTeachingSystem() async throws -> UserBasicInfo {
        let app = try await settings.ensureJwqywxLoggedIn()
        let response = try await app.getStudentBasicInfo()
        guard let basicInfo = response.message.first else {
            throw NSError(domain: "edu.cczu", code: -1, userInfo: [NSLocalizedDescriptionKey: "registration.profile.error.no_edu_info".localized])
        }
        return UserBasicInfo(
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
    }
#endif

    private func completeRegistration() async {
        if isSaving { return }
        isSaving = true

        do {
            // 基本校验（注册已在上一步完成）
            guard !nickname.trimmingCharacters(in: .whitespaces).isEmpty else {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "registration.profile.error.nickname_empty".localized
                }
                return
            }
            guard !realName.isEmpty else {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "registration.profile.error.no_edu_info".localized
                }
                return
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
        
        // 将图片数据写入临时文件
        let fileName = "\(userId)_avatar.jpg"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try imageData.write(to: tempURL)
        
        // 使用自定义图床上传
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        let url = try await ImageUploadService.uploadImage(at: tempURL)
        return url
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


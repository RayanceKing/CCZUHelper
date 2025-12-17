//
//  TeahouseLoginView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/14.
//

import SwiftUI
internal import Auth
import Supabase
#if canImport(CCZUKit)
import CCZUKit
#endif

/// 茶楼注册视图（支持登录切换）
struct TeahouseLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var teahouseService = TeahouseService()
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSignUp = false
    @State private var signUpStep: Int = 1  // 1: 邮箱密码, 2: 个人资料
    @State private var showError = false
    @State private var showProfileSetup = false
    
    // 注册资料
    @State private var nickname = ""
    @State private var avatarURL: String = ""
    @State private var realName = ""
    @State private var studentId = ""
    @State private var className = ""
    @State private var gradeText = ""
    @State private var collegeName = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                            .padding(.bottom, 8)
                        
                        Text(isSignUp ? "teahouse.register.title".localized : "teahouse.login.title".localized)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(isSignUp ? "teahouse.register.subtitle".localized : "teahouse.login.subtitle".localized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                .listRowBackground(Color.clear)
                
                Section {
                    TextField("teahouse.login.email.placeholder".localized, text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disabled(authViewModel.isLoading)
                    
                    SecureField("teahouse.login.password.placeholder".localized, text: $password)
                        .textContentType(.password)
                        .disabled(authViewModel.isLoading)
                        .onSubmit {
                            handleAuth()
                        }
                    if isSignUp {
                        SecureField("teahouse.register.confirm_password".localized, text: $confirmPassword)
                            .textContentType(.password)
                            .disabled(authViewModel.isLoading)
                        PasswordStrengthView(password: password)
                    }
                }
                
                Section {
                    VStack(spacing: 10) {
                        if #available(iOS 26.0, *) {
                            Button(action: handleAuth) {
                                HStack {
                                    if authViewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                    } else {
                                        if isSignUp && signUpStep == 1 {
                                            Text("registration.next_step".localized)
                                        } else {
                                            Text(isSignUp ? "teahouse.register.signup".localized : "teahouse.login.signin".localized)
                                        }
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
                            Button(action: handleAuth) {
                                HStack {
                                    if authViewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                    } else {
                                        if isSignUp && signUpStep == 1 {
                                            Text("registration.next_step".localized)
                                        } else {
                                            Text(isSignUp ? "teahouse.register.signup".localized : "teahouse.login.signin".localized)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .disabled(!canProceed || authViewModel.isLoading)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .buttonBorderShape(.automatic)
                        }
                        
                        Button(action: {
                            isSignUp.toggle()
                            signUpStep = 1  // 切换模式时重置步骤
                        }) {
                            Text(isSignUp ? "teahouse.register.has_account".localized : "teahouse.login.no_account".localized)
                                .font(.subheadline)
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle(isSignUp ? "teahouse.register.nav_title".localized : "teahouse.login.nav_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
            }
            .alert("teahouse.login.failed".localized, isPresented: $showError) {
                Button("ok".localized, role: .cancel) { }
            } message: {
                Text(authViewModel.errorMessage ?? "Unknown error")
            }
            .onChange(of: authViewModel.session) { _, newSession in
                if newSession != nil && !isSignUp {
                    dismiss()
                }
            }
            .onChange(of: signUpStep) { _, newStep in
                if isSignUp && newStep == 2 {
                    showProfileSetup = true
                }
            }
            .sheet(isPresented: $showProfileSetup) {
                RegistrationProfileSetupView(
                    email: email,
                    password: password,
                    onCancel: {
                        showProfileSetup = false
                        signUpStep = 1
                    },
                    onFinished: {
                        showProfileSetup = false
                        dismiss()
                    }
                )
                .environmentObject(authViewModel)
            }
        }
    }
    
    private var canProceed: Bool {
        guard !email.isEmpty && !password.isEmpty && email.contains("@") else { return false }
        if isSignUp {
            return password == confirmPassword && isStrongPassword(password)
        }
        return true
    }
    
    private func handleAuth() {
        guard canProceed else { return }
        
        Task {
            if isSignUp {
                if signUpStep == 1 {
                    // 拦截：需教务已登录且有缓存信息
                    let canProceedEdu = await validateEduInfo()
                    if !canProceedEdu {
                        showError = true
                        return
                    }
                    // 先完成注册（携带教务基础信息以满足后端触发器），再进入资料步骤
                    let metadata = buildMetadataFromCache()
                    await authViewModel.signUp(email: email, password: password, metadata: metadata)
                    if authViewModel.errorMessage != nil {
                        showError = true
                        return
                    }
                    signUpStep = 2
                }
            } else {
                // 登录逻辑
                await authViewModel.signIn(email: email, password: password)
                
                if authViewModel.errorMessage != nil {
                    showError = true
                } else if let uid = authViewModel.session?.user.id.uuidString {
                    // 登录成功后拉取服务器资料并同步到本地设置
                    Task {
                        do {
                            let profile = try await teahouseService.fetchProfile(userId: uid)
                            await MainActor.run {
                                settings.userDisplayName = profile.username
                            }
                        } catch {
                            // 失败时不阻断登录流程，仅记录错误
                            print("⚠️ 同步服务器资料失败: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    private func isStrongPassword(_ pwd: String) -> Bool {
        // 至少8位，包含大小写字母、数字和特殊字符
        let pattern = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[!@#$%^&*()_+=-]).{8,}$"
        return pwd.range(of: pattern, options: .regularExpression) != nil
    }

    private func validateEduInfo() async -> Bool {
        if hasCachedEduInfo() {
            return true
        }

#if canImport(CCZUKit)
        do {
            let app = try await settings.ensureJwqywxLoggedIn()
            let response = try await app.getStudentBasicInfo()
            guard let basic = response.message.first else {
                authViewModel.errorMessage = "registration.profile.error.no_edu_info".localized
                return false
            }
            cacheEduInfo(basic)
            return true
        } catch {
            authViewModel.errorMessage = "registration.profile.error.no_edu_info".localized
            return false
        }
#else
        authViewModel.errorMessage = "registration.profile.error.no_edu_info".localized
        return false
#endif
    }

    private func hasCachedEduInfo() -> Bool {
        let keyUser = "cachedUserInfo_\(settings.username ?? "anonymous")"
        if UserDefaults.standard.data(forKey: keyUser) != nil {
            return true
        }
        if UserDefaults.standard.data(forKey: "user_basic_info_cache") != nil {
            return true
        }
        return false
    }

    private func loadCachedEduInfo() -> UserBasicInfo? {
        let keyUser = "cachedUserInfo_\(settings.username ?? "anonymous")"
        if let data = UserDefaults.standard.data(forKey: keyUser),
           let info = try? JSONDecoder().decode(UserBasicInfo.self, from: data) {
            return info
        }
        if let data = UserDefaults.standard.data(forKey: "user_basic_info_cache"),
           let info = try? JSONDecoder().decode(UserBasicInfo.self, from: data) {
            return info
        }
        return nil
    }

    private func buildMetadataFromCache() -> [String: AnyJSON]? {
        guard let info = loadCachedEduInfo() else { return nil }
        var meta: [String: AnyJSON] = [:]
        meta["real_name"] = .string(info.name)
        meta["student_id"] = .string(info.studentNumber)
        meta["class_name"] = .string(info.className)
        meta["college_name"] = .string(info.collegeName)
        meta["grade"] = AnyJSON(integerLiteral: info.grade)
        return meta
    }

#if canImport(CCZUKit)
    private func cacheEduInfo(_ info: StudentBasicInfo) {
        let userInfo = UserBasicInfo(
            name: info.name,
            studentNumber: info.studentNumber,
            gender: info.gender,
            birthday: info.birthday,
            collegeName: info.collegeName,
            major: info.major,
            className: info.className,
            grade: info.grade,
            studyLength: info.studyLength,
            studentStatus: info.studentStatus,
            campus: info.campus,
            phone: info.phone,
            dormitoryNumber: info.dormitoryNumber,
            majorCode: info.majorCode,
            classCode: info.classCode,
            studentId: info.studentId,
            genderCode: info.genderCode
        )
        if let data = try? JSONEncoder().encode(userInfo) {
            let keyUser = "cachedUserInfo_\(settings.username ?? "anonymous")"
            UserDefaults.standard.set(data, forKey: keyUser)
            UserDefaults.standard.set(data, forKey: "user_basic_info_cache")
        }
    }
#endif
    
    private func submitProfileAndFinish() async {
        guard let userId = authViewModel.session?.user.id.uuidString else { return }
        let grade = Int(gradeText) ?? 0
        
        struct ProfileInsert: Codable {
            let id: String
            let realName: String
            let studentId: String
            let className: String
            let collegeName: String
            let grade: Int
            let username: String
            let avatarUrl: String?
            let createdAt: Date
            enum CodingKeys: String, CodingKey {
                case id
                case realName = "real_name"
                case studentId = "student_id"
                case className = "class_name"
                case collegeName = "college_name"
                case grade
                case username
                case avatarUrl = "avatar_url"
                case createdAt = "created_at"
            }
        }
        let payload = ProfileInsert(
            id: userId,
            realName: realName,
            studentId: studentId,
            className: className,
            collegeName: collegeName,
            grade: grade,
            username: nickname.isEmpty ? (authViewModel.session?.user.email ?? "") : nickname,
            avatarUrl: avatarURL.isEmpty ? nil : avatarURL,
            createdAt: Date()
        )
        do {
            _ = try await supabase
                .from("profiles")
                .upsert(payload)
                .execute()
            showProfileSetup = false
            dismiss()
        } catch {
            let errStr = error.localizedDescription
            if errStr.contains("duplicate key value violates unique constraint \"profiles_student_key\"") {
                authViewModel.errorMessage = "错误：一个人仅能注册一个账户，请检查教务系统信息"
            } else {
                authViewModel.errorMessage = errStr
            }
            showError = true
        }
    }
}

#Preview {
    TeahouseLoginView()
}

// 辅助视图：密码强度
struct PasswordStrengthView: View {
    let password: String
    var body: some View {
        let score = strengthScore(password)
        HStack {
            Text("teahouse.register.password_strength".localized)
            Spacer()
            Text(score.label)
                .foregroundStyle(score.color)
        }
        .font(.caption)
    }
    private func strengthScore(_ pwd: String) -> (label: String, color: Color) {
        var s = 0
        if pwd.count >= 8 { s += 1 }
        if pwd.range(of: "[A-Z]", options: .regularExpression) != nil { s += 1 }
        if pwd.range(of: "[a-z]", options: .regularExpression) != nil { s += 1 }
        if pwd.range(of: "[0-9]", options: .regularExpression) != nil { s += 1 }
        if pwd.range(of: "[!@#$%^&*()_+=-]", options: .regularExpression) != nil { s += 1 }
        switch s {
        case 0...2: return ("password.strength.weak".localized, .red)
        case 3...4: return ("password.strength.medium".localized, .orange)
        default: return ("password.strength.strong".localized, .green)
        }
    }
}

// 资料完善视图
struct ProfileSetupView: View {
    @Binding var nickname: String
    @Binding var avatarURL: String
    @Binding var realName: String
    @Binding var studentId: String
    @Binding var className: String
    @Binding var gradeText: String
    @Binding var collegeName: String
    let onSubmit: () async -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("profile_setup.nickname_section".localized) {
                    TextField("profile_setup.nickname".localized, text: $nickname)
                    TextField("profile_setup.avatar_url".localized, text: $avatarURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
                Section("profile_setup.student_info".localized) {
                    TextField("profile_setup.real_name".localized, text: $realName)
                    TextField("profile_setup.student_id".localized, text: $studentId)
                    TextField("profile_setup.class_name".localized, text: $className)
                    TextField("profile_setup.grade".localized, text: $gradeText)
                        .keyboardType(.numberPad)
                    TextField("profile_setup.college".localized, text: $collegeName)
                }
            }
            .navigationTitle("profile_setup.title".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("profile_setup.submit".localized) { Task { await onSubmit() } }
                        .disabled(!canSubmit)
                }
            }
        }
    }
    private var canSubmit: Bool {
        !realName.isEmpty && !studentId.isEmpty && !className.isEmpty && !collegeName.isEmpty && Int(gradeText) != nil
    }
}


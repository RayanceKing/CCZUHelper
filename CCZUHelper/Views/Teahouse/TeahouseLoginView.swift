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

// Safari URL wrapper for Identifiable
struct SafariURL: Identifiable {
    let id = UUID()
    let url: URL
}

/// 茶楼注册视图（支持登录切换）
struct TeahouseLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppSettings.self) private var settings
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var teahouseService = TeahouseService()
    
    @State private var email = ""
    @State private var password = ""
    @State private var showForget = false
    @Binding var resetPasswordToken: String?
    @State private var forceResetStep: iForgetView.ResetStep? = nil
    @State private var confirmPassword = ""
    @State private var isSignUp = false
    @State private var signUpStep: Int = 1  // 1: 邮箱密码, 2: 个人资料
    @State private var showError = false
    @State private var showProfileSetup = false
    @State private var agreedToTerms = false
    @State private var safariURL: SafariURL? = nil
    
    // 注册资料
    @State private var nickname = ""
    @State private var avatarURL: String = ""
    @State private var realName = ""
    @State private var studentId = ""
    @State private var className = ""
    @State private var gradeText = ""
    @State private var collegeName = ""
    
    private var titleSection: some View {
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
    }
    
    private var credentialsSection: some View {
        Section {
            TextField("teahouse.login.email.placeholder".localized, text: $email)
                .textContentType(isSignUp ? .username : .emailAddress)
                #if os(iOS) || os(tvOS) || os(visionOS)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textInputAutocapitalization(.never)
                #endif
                .disableAutocorrection(true)
                .disabled(authViewModel.isLoading)
            SecureField("teahouse.login.password.placeholder".localized, text: $password)
                .textContentType(isSignUp ? .newPassword : .password)
                .disableAutocorrection(true)
                #if os(iOS) || os(tvOS) || os(visionOS)
                .textInputAutocapitalization(.never)
                #endif
                .disabled(authViewModel.isLoading)
                .onSubmit {
                    handleAuth()
                }
            if isSignUp {
                SecureField("teahouse.register.confirm_password".localized, text: $confirmPassword)
                    .textContentType(.newPassword)
                    .disableAutocorrection(true)
                    #if os(iOS) || os(tvOS) || os(visionOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .disabled(authViewModel.isLoading)
                PasswordStrengthView(password: password)
            }
        }
    }
    
    var body: some View {
        #if os(macOS)
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 84, height: 84)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )

                    VStack(alignment: .leading, spacing: 8) {
                        Text(isSignUp ? "teahouse.register.title".localized : "teahouse.login.title".localized)
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(.primary)

                        Text(isSignUp ? "teahouse.register.subtitle".localized : "teahouse.login.subtitle".localized)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 16)

                VStack(spacing: 12) {
                    TextField("teahouse.login.email.placeholder".localized, text: $email)
                        .textContentType(isSignUp ? .username : .emailAddress)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .frame(height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.20 : 0.12), lineWidth: 1)
                                )
                        )
                        .disableAutocorrection(true)
                        .disabled(authViewModel.isLoading)

                    SecureField("teahouse.login.password.placeholder".localized, text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .frame(height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.20 : 0.12), lineWidth: 1)
                                )
                        )
                        .disableAutocorrection(true)
                        .disabled(authViewModel.isLoading)
                        .onSubmit { handleAuth() }

                    if isSignUp {
                        SecureField("teahouse.register.confirm_password".localized, text: $confirmPassword)
                            .textContentType(.newPassword)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .frame(height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(Color.primary.opacity(colorScheme == .dark ? 0.20 : 0.12), lineWidth: 1)
                                    )
                            )
                            .disableAutocorrection(true)
                            .disabled(authViewModel.isLoading)
                        PasswordStrengthView(password: password)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !isSignUp {
                        HStack {
                            Button("login.forgot_password".localized) {
                                showForget = true
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.blue)
                            Spacer()
                        }
                    }

                    if isSignUp && signUpStep == 1 {
                        HStack(spacing: 8) {
                            Button(action: { agreedToTerms.toggle() }) {
                                Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                                    .foregroundColor(agreedToTerms ? .blue : .gray)
                            }
                            .buttonStyle(.plain)

                            HStack(spacing: 0) {
                                Text(NSLocalizedString("login.terms_prefix", comment: "我已经阅读并同意"))
                                Button(action: { openWebDocument(WebsiteURLs.termsOfService) }) {
                                    Text(NSLocalizedString("login.terms_of_service", comment: "《用户协议》"))
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                Text(NSLocalizedString("common.and", comment: "和"))
                                Button(action: { openWebDocument(WebsiteURLs.privacyPolicy) }) {
                                    Text(NSLocalizedString("login.privacy_policy", comment: "《隐私权限》"))
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                            .font(.footnote)

                            Spacer()
                        }
                    }

                    HStack {
                        Button(action: {
                            isSignUp.toggle()
                            signUpStep = 1
                        }) {
                            Text(isSignUp ? "teahouse.register.has_account".localized : "teahouse.login.no_account".localized)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 14)

                Divider()
                    .overlay(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.10))

                HStack(spacing: 10) {
                    Spacer()

                    Button("common.cancel".localized) {
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Button(action: handleAuth) {
                        if authViewModel.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else if isSignUp && signUpStep == 1 {
                            Text("registration.next_step".localized)
                        } else {
                            Text(isSignUp ? "teahouse.register.signup".localized : "teahouse.login.signin".localized)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canProceed || authViewModel.isLoading)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }
            .frame(width: 700)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.10), lineWidth: 1)
                    )
            )
        }
        .alert("teahouse.login.failed".localized, isPresented: $showError) {
            Button("common.ok".localized, role: .cancel) { }
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
        .sheet(isPresented: $showForget, onDismiss: {
            resetPasswordToken = nil
            forceResetStep = nil
        }) {
            iForgetView(forceStep: $forceResetStep)
        }
        .onChange(of: resetPasswordToken) { _, newToken in
            if let token = newToken, !token.isEmpty {
                forceResetStep = .newPassword
                showForget = true
            }
        }
        .sheet(isPresented: $showProfileSetup) {
            RegistrationProfileSetupView(
                email: email,
                password: password,
                onCancel: {
                    showProfileSetup = false
                    Task {
                        // 删除注册中途取消的账户
                        await authViewModel.deleteAccount(email: email, password: password)
                        await teahouseService.clearTeahouseLoginState()
                        await MainActor.run {
                            signUpStep = 1
                        }
                    }
                },
                onFinished: {
                    showProfileSetup = false
                    dismiss()
                }
            )
            .environmentObject(authViewModel)
        }
        #else
        NavigationStack {
            Form {
                titleSection
                credentialsSection
                // 忘记密码按钮直接与页面融为一体，不被包裹
                if !isSignUp {
                    Button(action: {
                        showForget = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle.fill")
                            Text(NSLocalizedString("login.forgot_password", comment: "忘记密码？"))
                                .font(.subheadline)
                        }
                    }
                    .foregroundColor(.blue)
                    .buttonStyle(.plain)
                    // 无padding，紧贴密码输入框
                    .listRowBackground(Color.clear)
                    .sheet(isPresented: $showForget, onDismiss: {
                        resetPasswordToken = nil
                        forceResetStep = nil
                    }) {
                        iForgetView(forceStep: $forceResetStep)
                    }
                    .onChange(of: resetPasswordToken) { _, newToken in
                        if let token = newToken, !token.isEmpty {
                            forceResetStep = .newPassword
                            showForget = true
                        }
                    }
                }
                
                Section {
                    VStack(spacing: 10) {
                        if isSignUp && signUpStep == 1 {
                            HStack(spacing: 8) {
                                Button(action: {
                                    agreedToTerms.toggle()
                                }) {
                                    Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                                        .foregroundColor(agreedToTerms ? .blue : .gray)
                                }
                                .buttonStyle(.plain)
                                
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack(spacing: 0) {
                                        Text(NSLocalizedString("login.terms_prefix", comment: "我已经阅读并同意"))
                                        Button(action: {
                                            openWebDocument(WebsiteURLs.termsOfService)
                                        }) {
                                            Text(NSLocalizedString("login.terms_of_service", comment: "《用户协议》"))
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(.plain)
                                        Text(NSLocalizedString("common.and", comment: "和"))
                                        Button(action: {
                                            openWebDocument(WebsiteURLs.privacyPolicy)
                                        }) {
                                            Text(NSLocalizedString("login.privacy_policy", comment: "《隐私权限》"))
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .font(.footnote)
                                Spacer()
                            }
                        }
                        
                        if #available(iOS 26.0, macOS 26.0, *) {
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
                        
                        if !isSignUp {
                            // 已上移到密码输入框下方
                        }
                        
                        Button(action: {
                            isSignUp.toggle()
                            signUpStep = 1  // 切换模式时重置步骤
                        }) {
                            Text(isSignUp ? "teahouse.register.has_account".localized : "teahouse.login.no_account".localized)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle(isSignUp ? "teahouse.register.nav_title".localized : "teahouse.login.nav_title".localized)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
            }
            .alert("teahouse.login.failed".localized, isPresented: $showError) {
                Button("common.ok".localized, role: .cancel) { }
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
            #if canImport(UIKit)
            .sheet(item: $safariURL) { safariURL in
                SafariView(url: safariURL.url)
            }
            #endif
        }
        #endif
    }
    
    private var canProceed: Bool {
        guard !email.isEmpty && !password.isEmpty && email.contains("@") else { return false }
        if isSignUp {
            return password == confirmPassword && PasswordStrengthEvaluator.isAtLeastMedium(password) && agreedToTerms
        }
        return true
    }

    private func openWebDocument(_ urlString: String) {
        guard let url = URLFactory.makeURL(urlString) else {
            authViewModel.errorMessage = NSLocalizedString("error.invalid_link", comment: "链接无效，请稍后重试。")
            showError = true
            return
        }
        #if canImport(UIKit)
        safariURL = SafariURL(url: url)
        #else
        openURL(url)
        #endif
    }
    
    private func handleAuth() {
        guard canProceed else { return }
        
        Task {
            if isSignUp {
                if signUpStep == 1 {
                    // 第一步：检查和验证教务系统信息
                    // 1. 检查缓存
                    // 2. 检查教务系统登录状态
                    // 3. 从教务系统获取信息
                    let canProceedEdu = await validateEduInfo()
                    if !canProceedEdu {
                        showError = true
                        return
                    }
                    
                    // 第二步：使用教务系统信息进行Supabase注册
                    let metadata = buildMetadataFromCache()
                    await authViewModel.signUp(email: email, password: password, metadata: metadata)
                    
                    if authViewModel.errorMessage != nil {
                        showError = true
                        return
                    }
                    
                    // 第三步：进入资料补充步骤
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
                            print("⚠️ \(NSLocalizedString("error.sync_profile_failed", comment: "同步服务器资料失败")): \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    private func validateEduInfo() async -> Bool {
        // 第一步：检查是否是测试账户（邮箱）
        if TestData.isTestAccount(email) {
            // 测试账户：缓存样例数据并直接返回
            let sampleInfo = TestDataManager.getTestStudentInfo()
            await MainActor.run {
                cacheEduInfoDirect(sampleInfo)
            }
            authViewModel.errorMessage = nil
            return true
        }
        
        // 第二步：检查缓存中是否已有教务系统数据
        if hasCachedEduInfo() {
            authViewModel.errorMessage = nil
            return true
        }

        // 第三步：如果缓存没有，检查用户是否已登录教务系统
#if canImport(CCZUKit)
        let isLoggedInEdu = settings.isLoggedIn
        if !isLoggedInEdu {
            authViewModel.errorMessage = "registration.profile.error.not_logged_in_edu".localized
            return false
        }
        
        // 第四步：从教务系统获取信息
        do {
            let app = try await settings.ensureJwqywxLoggedIn()
            let response = try await app.getStudentBasicInfo()
            guard let basic = response.message.first else {
                authViewModel.errorMessage = "registration.profile.error.no_edu_info".localized
                return false
            }
            cacheEduInfo(basic)
            authViewModel.errorMessage = nil
            return true
        } catch {
            authViewModel.errorMessage = "registration.profile.error.fetch_edu_info_failed".localized
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
    
    /// 直接缓存 UserBasicInfo（用于测试账户）
    private func cacheEduInfoDirect(_ info: UserBasicInfo) {
        if let data = try? JSONEncoder().encode(info) {
            let keyUser = "cachedUserInfo_\(TestData.testUsername)"
            UserDefaults.standard.set(data, forKey: keyUser)
            UserDefaults.standard.set(data, forKey: "user_basic_info_cache")
        }
    }
    
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
                authViewModel.errorMessage = NSLocalizedString("error.duplicate_account", comment: "错误：一个人仅能注册一个账户，请检查教务系统信息")
            } else {
                authViewModel.errorMessage = errStr
            }
            showError = true
        }
    }
}

#Preview {
    @Previewable @State var token: String? = nil
    TeahouseLoginView(resetPasswordToken: $token)
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
        switch PasswordStrengthEvaluator.level(for: pwd) {
        case .weak:
            return ("password.strength.weak".localized, .red)
        case .medium:
            return ("password.strength.medium".localized, .orange)
        case .strong:
            return ("password.strength.strong".localized, .green)
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
                        #if os(iOS) || os(tvOS) || os(visionOS)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        #endif
                }
                Section("profile_setup.student_info".localized) {
                    TextField("profile_setup.real_name".localized, text: $realName)
                    TextField("profile_setup.student_id".localized, text: $studentId)
                    TextField("profile_setup.class_name".localized, text: $className)
                    TextField("profile_setup.grade".localized, text: $gradeText)
                        #if os(iOS) || os(tvOS) || os(visionOS)
                        .keyboardType(.numberPad)
                        #endif
                    TextField("profile_setup.college".localized, text: $collegeName)
                }
            }
            .navigationTitle("profile_setup.title".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized, action: onCancel)
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

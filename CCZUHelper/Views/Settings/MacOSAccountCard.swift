//
//  MacOSAccountCard.swift
//  CCZUHelper
//
//  Created by rayanceking on 2026/2/23.
//

import SwiftUI

#if os(macOS)

/// macOS 账户信息卡片组件
struct MacOSAccountCard: View {
    @Environment(AppSettings.self) private var settings
    @Binding var showLogoutConfirmation: Bool
    
    private var cachedTeachingUserInfo: UserBasicInfo? {
        let cacheKey = "cachedUserInfo_\(settings.username ?? "anonymous")"
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let info = try? JSONDecoder().decode(UserBasicInfo.self, from: data) else {
            return nil
        }
        return info
    }
    
    private var defaultUserImage: some View {
        Image(systemName: "person.crop.circle.badge.checkmark")
            .font(.system(size: 60))
            .foregroundStyle(.blue)
    }
    
    var body: some View {
        VStack(spacing: 18) {
            if settings.isLoggedIn {
                loggedInAccountCard
                    .frame(maxWidth: 560)

                Button(role: .destructive, action: {
                    showLogoutConfirmation = true
                }) {
                    HStack {
                        Spacer()
                        Text("settings.logout".localized)
                        Spacer()
                    }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: 360)
                .alert("settings.logout_confirm_title".localized, isPresented: $showLogoutConfirmation) {
                    Button("common.cancel".localized, role: .cancel) { }
                    Button("settings.logout".localized, role: .destructive) {
                        settings.logout()
                        NSApp.terminate(nil)
                    }
                } message: {
                    Text("settings.logout_confirm_message".localized)
                }
            } else {
                notLoggedInPrompt
                    .frame(maxWidth: 560)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 420, alignment: .center)
        .padding(.vertical, 8)
    }
    
    private var loggedInAccountCard: some View {
        VStack(spacing: 16) {
            accountHeader

            if let info = cachedTeachingUserInfo {
                InfoCard(title: "user_info.basic".localized) {
                    VStack(spacing: 12) {
                        UserInfoRow(label: "user_info.gender".localized, value: info.gender)
                        Divider()
                        UserInfoRow(label: "user_info.birthday".localized, value: info.birthday)
                        Divider()
                        UserInfoRow(label: "user_info.phone".localized, value: info.phone)
                    }
                }

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

                InfoCard(title: "user_info.campus_info".localized) {
                    VStack(spacing: 12) {
                        UserInfoRow(label: "user_info.campus".localized, value: info.campus)
                        Divider()
                        UserInfoRow(label: "user_info.dormitory".localized, value: info.dormitoryNumber)
                    }
                }
            } else {
                InfoCard(title: "user_info.title".localized) {
                    VStack(spacing: 10) {
                        UserInfoRow(label: "login.username.placeholder".localized, value: settings.username ?? "-")
                        Divider()
                        UserInfoRow(label: "settings.logged_in".localized, value: "settings.logged_in".localized)
                    }
                }
            }
        }
    }
    
    private var accountHeader: some View {
        HStack(spacing: 14) {
            defaultUserImage

            VStack(alignment: .leading, spacing: 6) {
                Text(cachedTeachingUserInfo?.name ?? settings.userDisplayName ?? settings.username ?? "common.user".localized)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(cachedTeachingUserInfo?.studentNumber ?? settings.username ?? "-")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("services.teaching_system".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
    
    private var notLoggedInPrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("settings.not_logged_in".localized)
                .font(.headline)
                .foregroundStyle(.primary)
            Text("settings.login_hint".localized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .quinarySystemFill))
        )
    }
}

#Preview {
    MacOSAccountCard(showLogoutConfirmation: .constant(false))
        .environment(AppSettings())
}

#endif

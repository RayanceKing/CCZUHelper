//
//  UserMenuButton.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/3.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// 用户菜单按钮组件
struct UserMenuButton: View {
    @Environment(AppSettings.self) private var settings
    @Binding var showUserSettings: Bool
    var isAuthenticated: Bool? = nil

    // 兼容旧用法（只传 showUserSettings）
    init(showUserSettings: Binding<Bool>) {
        self._showUserSettings = showUserSettings
        self.isAuthenticated = nil
    }
    // 新用法（传 showUserSettings 和 isAuthenticated）
    init(showUserSettings: Binding<Bool>, isAuthenticated: Bool?) {
        self._showUserSettings = showUserSettings
        self.isAuthenticated = isAuthenticated
    }
    
    private var isUserLoggedIn: Bool {
        isAuthenticated ?? settings.isLoggedIn
    }
    
    var body: some View {
        Button(action: { showUserSettings = true }) {
            if isUserLoggedIn {
                // 已登录：显示用户头像或默认图标
                if let avatarPath = settings.userAvatarPath {
                    #if os(macOS)
                    if let nsImage = NSImage(contentsOfFile: avatarPath) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.blue, lineWidth: 1.5)
                            )
                    } else {
                        defaultLoginImage
                    }
                    #else
                    if let uiImage = UIImage(contentsOfFile: avatarPath) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.blue, lineWidth: 1.5)
                            )
                    } else {
                        defaultLoginImage
                    }
                    #endif
                } else {
                    defaultLoginImage
                }
            } else {
                // 未登录显示默认图标
                Image(systemName: "person.crop.circle.badge.xmark")
                    .font(.title2)
                    .foregroundStyle(.gray)
            }
        }
    }
    
    private var defaultLoginImage: some View {
        Image(systemName: "person.crop.circle.badge.checkmark")
            .font(.title2)
            .foregroundStyle(.blue)
    }
}

#Preview {
    UserMenuButton(
        showUserSettings: .constant(false)
    )
    .environment(AppSettings())
}

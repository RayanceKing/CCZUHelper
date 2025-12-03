//
//  UserMenuButton.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/3.
//

import SwiftUI

/// 用户菜单按钮组件
struct UserMenuButton: View {
    @Environment(AppSettings.self) private var settings
    @Binding var showUserSettings: Bool
    
    var body: some View {
        Button(action: { showUserSettings = true }) {
            if settings.isLoggedIn {
                // 已登录显示用户头像
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.title2)
                    .foregroundStyle(.blue)
            } else {
                // 未登录显示默认图标
                Image(systemName: "person.crop.circle.badge.xmark")
                    .font(.title2)
                    .foregroundStyle(.gray)
            }
        }
    }
}

#Preview {
    UserMenuButton(
        showUserSettings: .constant(false)
    )
    .environment(AppSettings())
}

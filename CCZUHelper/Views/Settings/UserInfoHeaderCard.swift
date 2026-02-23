//
//  UserInfoHeaderCard.swift
//  CCZUHelper
//
//  Created by rayanceking on 2026/2/23.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// 用户信息头部卡片组件
struct UserInfoHeaderCard: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    
    @Binding var showLoginSheet: Bool
    
    #if os(macOS)
    let isSelectingOnMac: Bool
    let onSelectOnMac: () -> Void
    #else
    let onNavigateToUserInfo: () -> Void
    #endif
    
    private var defaultUserImage: some View {
        #if os(macOS)
        Image(systemName: "person.crop.circle.badge.checkmark")
            .font(.system(size: 60))
            .foregroundStyle(.blue)
        #else
        Image(systemName: "person.crop.circle.badge.checkmark")
            .font(.system(size: 50))
            .foregroundStyle(.blue)
        #endif
    }
    
    var body: some View {
        Section {
            if settings.isLoggedIn {
                #if os(macOS)
                Button(action: onSelectOnMac) {
                    userInfoContent
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.1))
                )
                #else
                NavigationLink {
                    UserInfoView().environment(settings)
                } label: {
                    userInfoContent
                }
                #endif
            } else {
                Button(action: {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showLoginSheet = true
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("settings.not_logged_in".localized)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("settings.login_hint".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
            }
        }
        #if os(macOS)
        .listRowBackground(Color.clear)
        #endif
    }
    
    private var userInfoContent: some View {
        HStack(spacing: 16) {
            #if os(macOS)
            let avatarSize: CGFloat = 60
            #else
            let avatarSize: CGFloat = 50
            #endif
            
            if let avatarPath = settings.userAvatarPath {
                #if canImport(UIKit)
                if let uiImage = UIImage(contentsOfFile: avatarPath) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                } else {
                    defaultUserImage
                }
                #else
                if let data = try? Data(contentsOf: URL(fileURLWithPath: avatarPath)),
                   let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                } else {
                    defaultUserImage
                }
                #endif
            } else {
                defaultUserImage
            }
            
            VStack(alignment: .leading, spacing: 6) {
                if let displayName = settings.userDisplayName ?? settings.username {
                    Text(displayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("settings.logged_in".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 12)
    }
}

#if os(macOS)
#Preview {
    UserInfoHeaderCard(
        showLoginSheet: .constant(false),
        isSelectingOnMac: false,
        onSelectOnMac: {}
    )
    .environment(AppSettings())
}
#else
#Preview {
    UserInfoHeaderCard(
        showLoginSheet: .constant(false),
        onNavigateToUserInfo: {}
    )
    .environment(AppSettings())
}
#endif

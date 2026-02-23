//
//  TeahouseProfileHeader.swift
//  CCZUHelper
//
//  Created by rayanceking on 2026/2/23.
//

import SwiftUI
internal import Auth

/// 用户档案头部组件 - 头像、名字、邮箱、自定义按钮
struct TeahouseProfileHeader: View {
    @Environment(AppSettings.self) private var settings
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    let serverProfile: Profile?
    let isLoadingProfile: Bool
    @Binding var showCustomizeProfile: Bool
    
    private var userEmail: String {
        authViewModel.session?.user.email ?? "common.unknown".localized
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

    #if os(macOS)
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("account.info".localized)
                .font(.headline)
                .padding(.horizontal, 2)

            VStack(spacing: 0) {
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

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)

                Divider().padding(.leading, 52)

                Button {
                    showCustomizeProfile = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.blue)
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.blue.opacity(0.14))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("profile.customize".localized)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .quinaryLabel))
            )
        }
    }
    #else
    var body: some View {
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
                showCustomizeProfile = true
            } label: {
                Text("profile.customize".localized)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.borderless)
        } header: {
            Text("account.info".localized)
        }
    }
    #endif
}

#Preview {
    TeahouseProfileHeader(
        serverProfile: nil,
        isLoadingProfile: false,
        showCustomizeProfile: .constant(false)
    )
    .environment(AppSettings())
    .environmentObject(AuthViewModel())
}

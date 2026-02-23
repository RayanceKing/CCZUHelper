//
//  OtherSettingsSections.swift
//  CCZUHelper
//
//  Created by rayanceking on 2026/2/23.
//

import SwiftUI

/// 其他功能和账户操作部分
struct OtherSettingsSections: View {
    @Environment(AppSettings.self) private var settings
    
    #if os(macOS)
    let onSelectNotifications: () -> Void
    #else
    let onNavigateToNotifications: () -> Void
    #endif
    
    @Binding var showLogoutConfirmation: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            // 其他功能
            otherFunctionsSection
            
            // 账户操作
            accountActionsSection
        }
    }
    
    private var otherFunctionsSection: some View {
        Section {
            #if os(macOS)
            Button(action: onSelectNotifications) {
                Label("settings.notifications".localized, systemImage: "bell")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            #else
            NavigationLink {
                NotificationSettingsView().environment(settings)
            } label: {
                Label("settings.notifications".localized, systemImage: "bell")
            }
            #endif

            Toggle(
                isOn: Binding(
                    get: { settings.enableICloudDataSync },
                    set: { settings.enableICloudDataSync = $0 }
                )
            ) {
                Label("settings.icloud_data_sync".localized, systemImage: "icloud")
            }

            Text("settings.icloud_data_sync_hint".localized)
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("settings.other".localized)
        }
    }
    
    private var accountActionsSection: some View {
        Section {
            if settings.isLoggedIn {
                Button(role: .destructive, action: {
                    showLogoutConfirmation = true
                }) {
                    HStack {
                        Spacer()
                        Text("settings.logout".localized)
                        Spacer()
                    }
                }
                .alert("settings.logout_confirm_title".localized, isPresented: $showLogoutConfirmation) {
                    Button("common.cancel".localized, role: .cancel) { }
                    Button("settings.logout".localized, role: .destructive) {
                        settings.logout()
                        #if os(macOS)
                        NSApp.terminate(nil)
                        #else
                        dismiss()
                        #endif
                    }
                } message: {
                    Text("settings.logout_confirm_message".localized)
                }
            }
        }
    }
}

#if os(macOS)
#Preview {
    OtherSettingsSections(
        onSelectNotifications: {},
        showLogoutConfirmation: .constant(false)
    )
    .environment(AppSettings())
}
#else
#Preview {
    OtherSettingsSections(
        onNavigateToNotifications: {},
        showLogoutConfirmation: .constant(false)
    )
    .environment(AppSettings())
}
#endif

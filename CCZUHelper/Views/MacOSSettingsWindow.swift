//
//  MacOSSettingsWindow.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/05.
//

import SwiftUI
import SwiftData

#if os(macOS)
/// macOS 专用设置窗口
struct MacOSSettingsWindow: View {
    @Environment(AppSettings.self) private var settings
    let onDone: (() -> Void)?
    
    @State private var showManageSchedules = false
    @State private var showLoginSheet = false
    @State private var showImagePicker = false
    
    var body: some View {
        UserSettingsView(
            showManageSchedules: $showManageSchedules,
            showLoginSheet: $showLoginSheet,
            showImagePicker: $showImagePicker,
            onDone: onDone
        )
        .environment(settings)
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView { url in
                settings.backgroundImagePath = url?.path
                settings.backgroundImageEnabled = (url != nil)
            }
        }
    }
}
#endif

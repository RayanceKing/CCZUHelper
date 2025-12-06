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
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    
    @Query private var schedules: [Schedule]
    
    @State private var showManageSchedules = false
    @State private var showLoginSheet = false
    @State private var showImagePicker = false
    
    var body: some View {
        UserSettingsView(
            showManageSchedules: $showManageSchedules,
            showLoginSheet: $showLoginSheet,
            showImagePicker: $showImagePicker
        )
        .environment(settings)
    }
}
#endif

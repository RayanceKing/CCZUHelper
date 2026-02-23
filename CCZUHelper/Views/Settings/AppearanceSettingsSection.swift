//
//  AppearanceSettingsSection.swift
//  CCZUHelper
//
//  Created by rayanceking on 2026/2/23.
//

import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// 外观设置部分组件
struct AppearanceSettingsSection: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    
    @Binding var showImagePicker: Bool
    
    var body: some View {
        Section("settings.appearance_settings".localized) {
            // 液晶玻璃效果开关
            #if canImport(SwiftUI)
            if #available(iOS 26, macOS 26, *) {
                Toggle(isOn: Binding(
                    get: { settings.useLiquidGlass },
                    set: { settings.useLiquidGlass = $0 }
                )) {
                    Text("settings.use_liquid_glass".localized)
                }
            }
            #endif
            
            // 课程块透明度调整
            courseBlockOpacityControl
            
            // 背景图片开关
            Toggle(isOn: Binding(
                get: { settings.backgroundImageEnabled && settings.backgroundImagePath != nil },
                set: { isOn in
                    if isOn {
                        #if os(macOS)
                        pickBackgroundImageOnMac()
                        #else
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showImagePicker = true
                        }
                        #endif
                    } else {
                        settings.backgroundImagePath = nil
                        settings.backgroundImageEnabled = false
                    }
                }
            )) {
                Label("settings.background_image".localized, systemImage: "photo")
            }
            
            // 背景透明度调整（仅在启用时显示）
            if settings.backgroundImageEnabled {
                backgroundOpacityControl
            }
        }
    }
    
    private var courseBlockOpacityControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("settings.course_block_opacity".localized, systemImage: "square.fill")
            
            if settings.useLiquidGlass {
                Text("settings.course_block_opacity_disabled_with_glass".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Slider(
                value: Binding(
                    get: { settings.courseBlockOpacity },
                    set: { settings.courseBlockOpacity = $0 }
                ),
                in: 0.5...1.0,
                step: 0.1,
                minimumValueLabel: Text("50%"),
                maximumValueLabel: Text("100%"),
                label: {
                    Text("settings.course_block_opacity".localized)
                }
            )
            .disabled(settings.useLiquidGlass)
            
            Text("\(Int(settings.courseBlockOpacity * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private var backgroundOpacityControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("settings.background_opacity".localized, systemImage: "slider.horizontal.below.circle.righthalf.filled.inverse")
            
            Slider(
                value: Binding(
                    get: { settings.backgroundOpacity },
                    set: { settings.backgroundOpacity = $0 }
                ),
                in: 0.0...1.0,
                step: 0.1,
                minimumValueLabel: Text("0%"),
                maximumValueLabel: Text("100%"),
                label: {
                    Text("settings.background_opacity".localized)
                }
            )
            
            Text("\(Int(settings.backgroundOpacity * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    #if os(macOS)
    private func pickBackgroundImageOnMac() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        guard panel.runModal() == .OK, let sourceURL = panel.url else {
            settings.backgroundImageEnabled = false
            return
        }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileExtension = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        let destinationURL = documentsPath.appendingPathComponent("background_\(timestamp).\(fileExtension)")

        let fileManager = FileManager.default
        if let existingFiles = try? fileManager.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil) {
            for file in existingFiles where file.lastPathComponent.hasPrefix("background_") {
                try? fileManager.removeItem(at: file)
            }
        }

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            settings.backgroundImagePath = destinationURL.path
            settings.backgroundImageEnabled = true
        } catch {
            settings.backgroundImagePath = nil
            settings.backgroundImageEnabled = false
        }
    }
    #endif
}

#Preview {
    AppearanceSettingsSection(showImagePicker: .constant(false))
        .environment(AppSettings())
}

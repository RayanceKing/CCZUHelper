//
//  TeachingSystemStatusBanner.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/6.
//

import SwiftUI

/// 教务系统状态横幅
struct TeachingSystemStatusBanner: View {
    let monitor = TeachingSystemMonitor.shared
    @State private var isExpanded = false

    var body: some View {
        if !monitor.isSystemAvailable {
            DisclosureGroup(
                isExpanded: $isExpanded,
                content: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(monitor.unavailableReason)
                            .font(.caption)
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                            Text("teaching_system.service_hours".localized)
                                .font(.caption2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                },
                label: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)

                        Text("teaching_system.system_closed".localized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            )
            .padding(.horizontal)
            .padding(.vertical, 8)
            .accentColor(.red) // 设置 DisclosureGroup 的箭头颜色
        }
    }
}

#Preview {
    TeachingSystemStatusBanner()
}

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
            VStack(spacing: 0) {
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.white)
                        
                        Text("teaching_system.system_closed".localized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.white)
                            .font(.caption)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                
                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(monitor.unavailableReason)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                        
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                            Text("teaching_system.service_hours".localized)
                                .font(.caption2)
                        }
                        .foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(Color.orange.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    TeachingSystemStatusBanner()
}

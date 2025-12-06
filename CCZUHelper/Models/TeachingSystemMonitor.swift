//
//  TeachingSystemMonitor.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/6.
//

import Foundation
import SwiftUI

/// 教务系统监控器
@Observable
class TeachingSystemMonitor {
    static let shared = TeachingSystemMonitor()
    
    /// 教务系统是否可用
    private(set) var isSystemAvailable: Bool = true
    
    /// 系统关闭原因
    private(set) var unavailableReason: String = ""
    
    private init() {
        checkSystemStatus()
    }
    
    /// 检查教务系统状态
    func checkSystemStatus() {
        // 检查时间段（23:00-6:00 系统维护）
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        
        if hour >= 23 || hour < 6 {
            isSystemAvailable = false
            unavailableReason = "teaching_system.closed_for_maintenance".localized
            return
        }
        
        // 如果时间段正常，则系统可用
        isSystemAvailable = true
        unavailableReason = ""
    }
    
    /// 显示系统关闭警告
    func showSystemUnavailableAlert() -> Alert {
        Alert(
            title: Text("teaching_system.unavailable_title".localized),
            message: Text(unavailableReason),
            dismissButton: .default(Text("ok".localized))
        )
    }
    
    /// 检查系统是否可用，如果不可用返回错误
    func validateSystemAvailability() throws {
        checkSystemStatus()
        if !isSystemAvailable {
            throw TeachingSystemError.systemClosed(reason: unavailableReason)
        }
    }
}

/// 教务系统错误类型
enum TeachingSystemError: LocalizedError {
    case systemClosed(reason: String)
    case networkUnreachable
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .systemClosed(let reason):
            return reason
        case .networkUnreachable:
            return "teaching_system.network_unreachable".localized
        case .serverError:
            return "teaching_system.server_error".localized
        }
    }
}

/// 教务系统状态视图修饰符
struct TeachingSystemStatusModifier: ViewModifier {
    @State private var showAlert = false
    let monitor = TeachingSystemMonitor.shared
    
    func body(content: Content) -> some View {
        content
            .alert("teaching_system.unavailable_title".localized, isPresented: $showAlert) {
                Button("ok".localized, role: .cancel) { }
            } message: {
                Text(monitor.unavailableReason)
            }
            .onAppear {
                monitor.checkSystemStatus()
                if !monitor.isSystemAvailable {
                    showAlert = true
                }
            }
    }
}

extension View {
    /// 添加教务系统状态检测
    func checkTeachingSystemStatus() -> some View {
        modifier(TeachingSystemStatusModifier())
    }
}

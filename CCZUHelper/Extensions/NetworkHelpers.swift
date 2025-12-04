//
//  NetworkHelpers.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/04.
//

import Foundation

/// 网络请求相关的错误类型
enum NetworkError: Error, LocalizedError {
    case credentialsMissing
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .credentialsMissing:
            return "密码丢失，请重新登录"
        case .timeout:
            return "请求超时，教务系统可能无法访问"
        }
    }
}

/// 为异步操作添加超时功能的辅助函数
/// - Parameters:
///   - seconds: 超时秒数
///   - operation: 需要执行的异步操作
/// - Returns: 异步操作的结果
/// - Throws: 如果操作超时或失败，则抛出错误
func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // 添加主要任务
        group.addTask {
            return try await operation()
        }
        // 添加超时任务
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw NetworkError.timeout
        }
        
        // 等待第一个完成的任务并获取结果
        let result = try await group.next()!
        
        // 取消所有其他任务
        group.cancelAll()
        
        return result
    }
}

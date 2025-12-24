//
//  SupabaseClient.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/13.
//

import Supabase
import Foundation

/// 配置 JSON 解码器以正确处理 Supabase 的日期格式
private let supabaseJSONDecoder: JSONDecoder = {
    let decoder = JSONDecoder()
    // Supabase 返回 ISO 8601 格式的 timestamptz
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}()

/// 配置 JSON 编码器
private let supabaseJSONEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
}()

/// Supabase 客户端实例
let supabase = SupabaseClient(
    supabaseURL: URL(string: SupabaseConstants.projectURL)!,
    supabaseKey: SupabaseConstants.anonKey,
    options: SupabaseClientOptions(
        db: .init(schema: "public"),
        auth: .init(autoRefreshToken: true),
        global: .init(
            headers: [:],
            session: .shared
        )
    )
)

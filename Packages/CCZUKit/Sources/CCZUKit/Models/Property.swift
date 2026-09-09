import Foundation

/// 客户端属性
public enum Property: Sendable {
    case string(String)
    case int(Int)
    case bool(Bool)

    public var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }

    public var intValue: Int? {
        if case .int(let value) = self {
            return value
        }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let value) = self {
            return value
        }
        return nil
    }
}

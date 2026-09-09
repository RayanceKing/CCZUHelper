import Foundation

/// 账号信息
public struct Account: Sendable {
    public let username: String
    public let password: String

    public init(username: String = "", password: String = "") {
        self.username = username
        self.password = password
    }

    public static let `default` = Account()
}

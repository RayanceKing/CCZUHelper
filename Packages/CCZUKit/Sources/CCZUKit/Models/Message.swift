import Foundation

// MARK: - 通用响应消息
public struct Message<T: Decodable>: Decodable, Sendable where T: Sendable {
    public let status: Int
    public let message: [T]
    public let token: String?

    enum CodingKeys: String, CodingKey {
        case status
        case message
        case token
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(Int.self, forKey: .status)
        token = try container.decodeIfPresent(String.self, forKey: .token)

        guard status == 0 else { throw TeachingResponseError.rejected(status: status) }
        // Do not turn invalid responses or malformed rows into a successful empty list.
        message = try container.decode([T].self, forKey: .message)
    }
}

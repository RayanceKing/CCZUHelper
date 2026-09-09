import Foundation

/// 教务企业微信应用
@MainActor
public final class JwqywxApplication {
    var loginTask: Task<Message<LoginUserData>, Error>?
    var authenticationGeneration = 0
    let client: DefaultHTTPClient
    var authorizationToken: String?
    var authorizationId: String?
    var studentNumber: String?
    var customHeaders: [String: String]
    var trainingPlanCache: TrainingPlan?
    public internal(set) var lastTrainingPlanRawResponse: String?
    public var enableDebugLogging: Bool = false

    public init(client: DefaultHTTPClient) {
        self.client = client
        self.customHeaders = CCZUConstants.defaultHeaders
        self.customHeaders["Referer"] = CCZUConstants.Jwqywx.referer
        self.customHeaders["Origin"] = CCZUConstants.Jwqywx.origin
    }
}

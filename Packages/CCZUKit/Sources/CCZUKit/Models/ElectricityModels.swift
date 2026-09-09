import Foundation

// MARK: - 校区信息
public struct ElectricityArea: Codable, Sendable {
    public let area: String                    // 校区名称
    public let areaname: String                // 校区显示名称
    public let aid: String                     // 校区ID

    public init(area: String, areaname: String, aid: String) {
        self.area = area
        self.areaname = areaname
        self.aid = aid
    }
}

// MARK: - 建筑物信息
public struct Building: Codable, Sendable {
    public let building: String                // 建筑物名称
    public let buildingid: String              // 建筑物ID

    public init(building: String, buildingid: String) {
        self.building = building
        self.buildingid = buildingid
    }
}

// MARK: - 房间信息
public struct Room: Codable, Sendable {
    public let room: String                    // 房间号
    public let roomid: String                  // 房间ID

    public init(room: String, roomid: String) {
        self.room = room
        self.roomid = roomid
    }
}

// MARK: - 电费查询响应
public struct ElectricityResponse: Decodable, Sendable {
    public let errmsg: String                  // 错误消息/电费信息
    public let errcode: Int?                   // 错误代码

    enum CodingKeys: String, CodingKey {
        case errmsg
        case errcode
    }
}

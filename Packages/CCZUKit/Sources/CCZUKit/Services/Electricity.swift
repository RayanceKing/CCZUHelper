import Foundation

extension JwqywxApplication {
    public func getElectricityAreas() async throws -> [ElectricityArea] {
        CCZUConstants.Electricity.predefinedAreas.map {
            ElectricityArea(area: $0.area, areaname: $0.areaname, aid: $0.aid)
        }
    }

    /// 获取指定校区的建筑物列表
    /// - Parameter area: 校区信息
    /// - Returns: 建筑物列表
    public func getBuildings(area: ElectricityArea) async throws -> [Building] {
        let url = CCZUConstants.Electricity.queryBuildingURL

        let areaJSON = """
        {"areaname":"\(area.areaname)","area":"\(area.area)"}
        """

        let payload: [String: String] = [
            "account": CCZUConstants.Electricity.account,
            "area": areaJSON,
            "aid": area.aid
        ]

        var headers = customHeaders
        headers["User-Agent"] = CCZUConstants.Electricity.buildingUserAgent

        let (data, response) = try await client.postForm(url: url, headers: headers, formData: payload)

        guard response.statusCode == 200 else {
            throw CCZUError.networkError(NSError(domain: "HTTP", code: response.statusCode))
        }

        // 使用 JSONSerialization 手动解析，因为后端返回的 JSON 格式可能不标准
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let buildingArray = json["buildingtab"] as? [[String: Any]] else {
            return []
        }

        let buildings = buildingArray.compactMap { buildingDict -> Building? in
            guard let building = buildingDict["building"] as? String,
                  let buildingid = buildingDict["buildingid"] as? String else {
                return nil
            }
            return Building(building: building, buildingid: buildingid)
        }

        return buildings
    }

    /// 查询电费信息
    /// - Parameters:
    ///   - area: 校区信息
    ///   - building: 建筑物信息
    ///   - roomId: 房间ID
    /// - Returns: 电费查询结果
    public func queryElectricity(area: ElectricityArea, building: Building, roomId: String) async throws -> ElectricityResponse {
        let url = CCZUConstants.Electricity.queryRoomURL

        let areaDict: [String: String] = ["area": area.area, "areaname": area.areaname]
        let buildingDict: [String: String] = ["building": building.building, "buildingid": building.buildingid]
        let floorDict: [String: String] = ["floorid": "", "floor": ""]
        let roomDict: [String: String] = ["room": "", "roomid": roomId]

        let areaJson = try String(data: JSONEncoder().encode(areaDict), encoding: .utf8) ?? ""
        let buildingJson = try String(data: JSONEncoder().encode(buildingDict), encoding: .utf8) ?? ""
        let floorJson = try String(data: JSONEncoder().encode(floorDict), encoding: .utf8) ?? ""
        let roomJson = try String(data: JSONEncoder().encode(roomDict), encoding: .utf8) ?? ""

        let payload: [String: String] = [
            "aid": area.aid,
            "account": CCZUConstants.Electricity.account,
            "area": areaJson,
            "building": buildingJson,
            "floor": floorJson,
            "room": roomJson
        ]

        var headers = customHeaders
        headers["User-Agent"] = CCZUConstants.Electricity.roomUserAgent

        let (data, response) = try await client.postForm(url: url, headers: headers, formData: payload)

        guard response.statusCode == 200 else {
            throw CCZUError.networkError(NSError(domain: "HTTP", code: response.statusCode))
        }

        let decoder = JSONDecoder()
        return try decoder.decode(ElectricityResponse.self, from: data)
    }
}

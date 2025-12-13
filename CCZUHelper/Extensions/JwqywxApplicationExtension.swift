//
//  JwqywxApplicationExtension.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/08.
//

import Foundation
//import CCZUKit
import CCZUNISwiftBridge

/// JwqywxApplication 扩展 - 处理电费查询相关的 API 调用
extension JwqywxApplication {
    
    /// 获取电费查询的建筑物列表（修复 API 响应格式问题）
    /// - Parameters:
    ///   - area: 校区信息
    ///   - client: HTTP 客户端
    /// - Returns: 建筑物列表
    static func getElectricityBuildings(area: ElectricityArea, client: HTTPClient) async throws -> [Building] {
        guard let url = URL(string: "http://wxxy.cczu.edu.cn/wechat/callinterface/queryElecBuilding.html") else {
            throw NSError(domain: "ElectricityQuery", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        let areaJSON = """
        {"areaname":"\(area.areaname)","area":"\(area.area)"}
        """
        
        let payload: [String: String] = [
            "account": "1",
            "area": areaJSON,
            "aid": area.aid
        ]
        
        let (data, _) = try await client.postForm(url: url, headers: [:], formData: payload)
        
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
}



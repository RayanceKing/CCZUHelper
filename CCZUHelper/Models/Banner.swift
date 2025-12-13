//
//  Banner.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/13.
//

import Foundation
import Combine

struct Banner: Identifiable, Codable {
    let id: UUID
    let title: String
    let content: String
    let color: String
    let startDate: Date
    let endDate: Date
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case color
        case startDate = "start_date"
        case endDate = "end_date"
        case isActive = "is_active"
    }
}

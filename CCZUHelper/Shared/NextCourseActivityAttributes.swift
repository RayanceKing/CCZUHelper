//
//  NextCourseActivityAttributes.swift
//  CCZUHelper
//
//  Created by rayanceking on 2026/2/23.
//

#if os(iOS) && canImport(ActivityKit)
import ActivityKit
import Foundation

nonisolated struct NextCourseActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        var courseName: String
        var location: String
        var startDate: Date
        var endDate: Date
        var progressStartDate: Date
    }

    var identifier: String
}
#endif

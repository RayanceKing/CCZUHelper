//
//  Item.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/11/30.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

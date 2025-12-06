//
//  LocalizationExtension.swift
//  CCZUHelperLite Watch App
//
//  Created by rayanceking on 2025/12/6.
//

import Foundation

extension String {
    /// 获取本地化字符串
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
}

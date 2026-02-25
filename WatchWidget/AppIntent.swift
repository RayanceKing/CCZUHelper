//
//  AppIntent.swift
//  WatchWidget
//
//  Created by rayanceking on 2026/2/24.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "课表小组件" }
    static var description: IntentDescription { "显示今天下节课信息" }
}

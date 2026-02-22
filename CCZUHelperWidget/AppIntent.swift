//
//  AppIntent.swift
//  CCZUHelperWidget
//
//  Created by rayanceking on 2025/12/4.
//

import WidgetKit
import AppIntents

enum WidgetAutoRefreshInterval: String, AppEnum {
    case smart
    case fifteenMinutes
    case thirtyMinutes
    case sixtyMinutes
    case oneHundredTwentyMinutes

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "widget.intent.refresh_interval.type")
    }

    static var caseDisplayRepresentations: [WidgetAutoRefreshInterval: DisplayRepresentation] {
        [
            .smart: DisplayRepresentation(title: "widget.intent.refresh_interval.smart"),
            .fifteenMinutes: DisplayRepresentation(title: "widget.intent.refresh_interval.15m"),
            .thirtyMinutes: DisplayRepresentation(title: "widget.intent.refresh_interval.30m"),
            .sixtyMinutes: DisplayRepresentation(title: "widget.intent.refresh_interval.60m"),
            .oneHundredTwentyMinutes: DisplayRepresentation(title: "widget.intent.refresh_interval.120m")
        ]
    }

    var minutes: Int? {
        switch self {
        case .smart:
            return nil
        case .fifteenMinutes:
            return 15
        case .thirtyMinutes:
            return 30
        case .sixtyMinutes:
            return 60
        case .oneHundredTwentyMinutes:
            return 120
        }
    }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "widget.intent.configuration.title" }
    static var description: IntentDescription { "widget.intent.configuration.description" }

    @Parameter(title: "widget.intent.configuration.auto_refresh", default: .smart)
    var autoRefreshInterval: WidgetAutoRefreshInterval
}

struct ManualRefreshWidgetIntent: AppIntent {
    static var title: LocalizedStringResource { "widget.intent.manual_refresh.title" }
    static var description = IntentDescription("widget.intent.manual_refresh.description")

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadTimelines(ofKind: "CCZUHelperWidget")
        return .result()
    }
}

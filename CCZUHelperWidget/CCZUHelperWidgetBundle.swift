//
//  CCZUHelperWidgetBundle.swift
//  CCZUHelperWidget
//
//  Created by rayanceking on 2025/12/4.
//

import WidgetKit
import SwiftUI

@main
struct CCZUHelperWidgetBundle: WidgetBundle {
    var body: some Widget {
        CCZUHelperWidget()
        #if os(iOS)
        if #available(iOSApplicationExtension 16.2, *) {
            NextCourseLiveActivityWidget()
        }
        #endif
    }
}

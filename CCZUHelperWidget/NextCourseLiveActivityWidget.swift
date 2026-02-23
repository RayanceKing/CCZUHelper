  //
  //  NextCourseLiveActivityWidget.swift
  //  CCZUHelperWidget
  //
  //  Created by Codex on 2026/2/23.
  //

  #if os(iOS) && canImport(ActivityKit)
  import ActivityKit
  import WidgetKit
  import SwiftUI

  struct NextCourseActivityAttributes: ActivityAttributes {
      public struct ContentState: Codable, Hashable {
          var courseName: String
          var location: String
          var startDate: Date
          var endDate: Date
          var progressStartDate: Date
      }

      var identifier: String
  }

  @available(iOSApplicationExtension 16.2, *)
  struct NextCourseLiveActivityWidget: Widget {
      var body: some WidgetConfiguration {
          ActivityConfiguration(for: NextCourseActivityAttributes.self) { context in
              let state = context.state
              VStack(alignment: .leading, spacing: 8) {
                  HStack(alignment: .top, spacing: 8) {
                      Text("live_activity.next_course".localized)
                          .font(.caption)
                          .foregroundStyle(.secondary)
                          .lineLimit(1)
                      Spacer()
                      Text(countdownText(for: state.startDate))
                          .font(.headline)
                          .monospacedDigit()
                          .lineLimit(1)
                          .minimumScaleFactor(0.8)
                  }

                  Text(state.courseName)
                      .font(.headline)
                      .lineLimit(1)
                      .minimumScaleFactor(0.85)
                  Text(state.location)
                      .font(.caption)
                      .foregroundStyle(.secondary)
                      .lineLimit(1)

                  NextCourseLinearProgressView(state: state)
              }
              .padding(.horizontal, 12)
              .padding(.vertical, 10)
              .activityBackgroundTint(.clear)
              .activitySystemActionForegroundColor(.blue)
          } dynamicIsland: { context in
              let state = context.state
              return DynamicIsland {
                  DynamicIslandExpandedRegion(.leading) {
                      HStack(spacing: 4) {
                          Image(systemName: "book.closed")
                              .foregroundStyle(.secondary)
                      }
                      .padding(.leading, 4)
                  }
                  DynamicIslandExpandedRegion(.trailing) {
                      Text(countdownText(for: state.startDate))
                          .font(.caption)
                          .monospacedDigit()
                          .lineLimit(1)
                          .minimumScaleFactor(0.85)
                          .padding(.trailing, 4)
                  }
                  DynamicIslandExpandedRegion(.center) {
                      VStack(alignment: .leading, spacing: 2) {
                          Text("live_activity.next_course".localized)
                              .font(.caption2)
                              .foregroundStyle(.secondary)
                          Text(state.courseName)
                              .font(.headline)
                              .lineLimit(1)
                              .minimumScaleFactor(0.85)
                          Text(state.location)
                              .font(.caption2)
                              .foregroundStyle(.secondary)
                              .lineLimit(1)
                      }
                      .padding(.horizontal, 4)
                  }
                  DynamicIslandExpandedRegion(.bottom) {
                      NextCourseLinearProgressView(state: state)
                          .padding(.horizontal, 8)
                  }
              } compactLeading: {
                  Image(systemName: "book.closed")
              } compactTrailing: {
                  NextCourseCircularProgressView(state: state)
              } minimal: {
                  Image(systemName: "book.closed")
              }
              .widgetURL(URL(string: "edupal://open/schedule"))
              .keylineTint(.blue)
          }
      }
  }

  @available(iOSApplicationExtension 16.2, *)
  private struct NextCourseLinearProgressView: View {
      let state: NextCourseActivityAttributes.ContentState

      var body: some View {
          GeometryReader { geo in
              let fraction = progressFraction
              ZStack(alignment: .leading) {
                  Capsule(style: .continuous)
                      .fill(Color.white.opacity(0.14))
                  Capsule(style: .continuous)
                      .fill(Color.blue)
                      .frame(width: geo.size.width * fraction)
              }
          }
          .frame(height: 8)
      }

      private var progressFraction: CGFloat {
          let total = state.startDate.timeIntervalSince(state.progressStartDate)
          guard total > 0 else { return 1.0 }
          let elapsed = Date().timeIntervalSince(state.progressStartDate)
          let value = elapsed / total
          return CGFloat(min(1.0, max(0.0, value)))
      }
  }

  @available(iOSApplicationExtension 16.2, *)
  private struct NextCourseCircularProgressView: View {
      let state: NextCourseActivityAttributes.ContentState

      var body: some View {
          ProgressView(value: progressFraction, total: 1.0)
              .progressViewStyle(.circular)
              .tint(.blue)
      }

      private var progressFraction: Double {
          let total = state.startDate.timeIntervalSince(state.progressStartDate)
          guard total > 0 else { return 1.0 }
          let elapsed = Date().timeIntervalSince(state.progressStartDate)
          return min(1.0, max(0.0, elapsed / total))
      }
  }

  // Helper function for countdown text
  private func countdownText(for startDate: Date) -> String {
      let now = Date()
      let interval = startDate.timeIntervalSince(now)

      if interval <= 0 {
          return "已开始"
      }

      let minutes = Int(interval) / 60
      let hours = minutes / 60
      let remainingMinutes = minutes % 60

      if hours > 0 {
          return "\(hours)小时\(remainingMinutes)分"
      } else if remainingMinutes > 0 {
          return "\(remainingMinutes)分钟"
      } else {
          return "即将开始"
      }
  }
  #endif

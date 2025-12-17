//
//  FloatingTabButton.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/17.
//

import SwiftUI

struct FloatingTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    // 可选：交互与风格开关
    private var isInteractive: Bool { true }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(
                    {
                        if #available(iOS 26.0, macOS 15.0, *) {
                            return isSelected ? AnyShapeStyle(.black) : AnyShapeStyle(.white)
                        } else {
                            return isSelected ? AnyShapeStyle(.black) : AnyShapeStyle(.primary.opacity(0.7))
                        }
                    }()
                )
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if #available(iOS 26.0, macOS 15.0, *) {
                            if isSelected {
                                Capsule().fill(.white)
                            } else {
                                Capsule().glassEffect(.regular.interactive())
                            }
                        } else {
                            #if os(macOS)
                            RoundedRectangle(cornerRadius: 100)
                                .fill(isSelected ? Color.blue : Color(nsColor: .controlBackgroundColor))
                            #else
                            RoundedRectangle(cornerRadius: 100)
                                .fill(isSelected ? Color.blue : Color(.systemGray5))
                            #endif
                        }
                    }
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            Color.white.opacity(isSelected ? 0.3 : 0.1),
                            lineWidth: 0.5
                        )
                )
                .animation(.easeInOut(duration: 0.25), value: isSelected)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.95))
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    let scale: CGFloat
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

//
//  PriceTagView.swift
//  CCZUHelper
//
//  Created by GitHub Copilot on 2025/12/15.
//

import SwiftUI

struct PriceTagView: View {
    let price: Double
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "tag.fill")
                .foregroundStyle(.white)
            Text(String(format: "¥%.2f", price))
                .fontWeight(.semibold)
        }
        .font(.footnote)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color.orange.gradient)
        )
    }
}

#Preview {
    PriceTagView(price: 99.0)
        .padding()
}

// CategoryBarOverlay.swift
// CCZUHelper
//
// 顶部横向可滚动 Tab（玻璃风格适配 SwiftUI 5/5.1/5.2/5.3/5.4/5.5/5.6/5.7/5.8/5.9/5.10/5.11/5.12/5.13/5.14/5.15/5.16/5.17/5.18/5.19/5.20/5.21/5.22/5.23/5.24/5.25/5.26）

#if swift(>=5.9)
import SwiftUI
#else
import SwiftUI
#endif

struct CategoryBarOverlay: View {
    let categories: [CategoryItem]
    @Binding var selectedCategory: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories) { category in
                    CategoryTag(
                        title: category.title,
                        isSelected: selectedCategory == category.id
                    ) {
                        withAnimation {
                            selectedCategory = category.id
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview {
    CategoryBarOverlay(
        categories: [
            CategoryItem(id: 0, title: "全部", backendValue: nil),
            CategoryItem(id: 1, title: "学习", backendValue: "学习"),
            CategoryItem(id: 2, title: "生活", backendValue: "生活")
        ],
        selectedCategory: .constant(0)
    )
}
#endif

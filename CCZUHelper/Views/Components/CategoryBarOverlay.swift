// CategoryBarOverlay.swift
// CCZUHelper
//
// 顶部横向可滚动 Tab

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

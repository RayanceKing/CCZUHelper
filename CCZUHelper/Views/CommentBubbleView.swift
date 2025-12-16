import SwiftUI

struct CommentBubbleView: View {
    let content: String
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
            Text(content)
                .font(.body)
                .foregroundStyle(.primary)
                .padding(10)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

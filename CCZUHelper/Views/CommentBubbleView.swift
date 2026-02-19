import SwiftUI

struct CommentBubbleView: View {
    let content: String
    var body: some View {
        Text(content)
            .font(.body)
            .foregroundStyle(.primary)
            .padding(.vertical, 4)
        .fixedSize(horizontal: false, vertical: true)
    }
}

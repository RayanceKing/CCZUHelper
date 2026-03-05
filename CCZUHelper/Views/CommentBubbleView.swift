import SwiftUI
import MarkdownUI

struct CommentBubbleView: View {
    let content: String
    var body: some View {
        Markdown(content)
            .markdownTheme(.gitHub)
            .background(Color.clear)
            .font(.body)
            .foregroundStyle(.primary)
            .padding(.vertical, 4)
            .fixedSize(horizontal: false, vertical: true)
    }
}

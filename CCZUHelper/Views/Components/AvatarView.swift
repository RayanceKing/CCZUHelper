import SwiftUI
import Kingfisher

struct AvatarView: View {
    let avatarUrl: URL?
    let isAnonymous: Bool?
    var body: some View {
        Group {
            if let url = avatarUrl {
                KFImage(url)
                    .placeholder { Circle().fill(Color.gray.opacity(0.3)) }
                    .retry(maxCount: 2, interval: .seconds(2))
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: isAnonymous == true ? "questionmark" : "person.fill")
                            .foregroundColor(.gray)
                    )
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
    }
}

import SwiftUI

struct SuccessCheckmarkView: View {
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .resizable()
            .frame(width: 72, height: 72)
            .foregroundColor(.green)
            .padding(.bottom, 20)
    }
}

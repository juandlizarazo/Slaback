import SwiftUI

struct AvatarView: View {
    let name: String
    let colorHex: String
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.15)
                .fill(Color(slackColor: colorHex))
            Text(initial)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }

    private var initial: String {
        String(name.prefix(1)).uppercased()
    }
}

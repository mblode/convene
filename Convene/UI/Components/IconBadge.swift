import SwiftUI

struct IconBadge: View {
    let systemName: String
    var size: CGFloat = 32
    var iconSize: CGFloat = 15
    var tint: Color = .textPrimary
    var background: Color = .iconBadgeBackground

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.iconBadge, style: .continuous)
            .fill(background)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(tint)
            )
    }
}

import SwiftUI

enum Theme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let pageHorizontal: CGFloat = 40
        static let pageVertical: CGFloat = 32
        static let sectionGap: CGFloat = 28
        static let rowVertical: CGFloat = 14
        static let rowHorizontal: CGFloat = 16
    }

    enum Radius {
        static let card: CGFloat = 16
        static let iconBadge: CGFloat = 10
        static let menu: CGFloat = 10
        static let control: CGFloat = 6
        static let bubble: CGFloat = 16
    }

    enum Stroke {
        static let hairline: CGFloat = 1
    }

    struct ShadowToken {
        let color: Color
        let radius: CGFloat
        let y: CGFloat
    }

    enum Shadow {
        static let menu = ShadowToken(color: .black.opacity(0.20), radius: 8, y: 2)
    }
}

extension View {
    func themeShadow(_ token: Theme.ShadowToken) -> some View {
        shadow(color: token.color, radius: token.radius, x: 0, y: token.y)
    }
}

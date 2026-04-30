import SwiftUI

struct DashedDivider: View {
    var color: Color = .dividerWarm

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: .init(x: 0, y: 0.5))
                path.addLine(to: .init(x: proxy.size.width, y: 0.5))
            }
            .stroke(
                color,
                style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 4])
            )
        }
        .frame(height: 1)
    }
}

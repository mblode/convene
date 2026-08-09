import SwiftUI

struct DashedDivider: View {
    var color: Color = .dividerWarm

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
    }
}

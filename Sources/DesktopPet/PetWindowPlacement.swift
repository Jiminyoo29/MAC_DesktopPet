import CoreGraphics
import Foundation

enum PetWindowMetrics {
    static let baseWidth: CGFloat = 190
    static let baseHeight: CGFloat = 250

    static func size(scale: Double) -> CGSize {
        CGSize(width: baseWidth * scale, height: baseHeight * scale)
    }
}

enum PetWindowPlacement {
    static func resolvedOrigin(
        savedOrigin: WindowOrigin?,
        screen: CGRect,
        size: CGSize,
        offsetIndex: Int
    ) -> CGPoint {
        let proposed = savedOrigin?.point ?? CGPoint(
            x: screen.maxX - size.width - 60 - CGFloat(offsetIndex * 36),
            y: screen.midY - size.height / 2 - CGFloat(offsetIndex * 30)
        )

        return CGPoint(
            x: min(max(proposed.x, screen.minX), screen.maxX - size.width),
            y: min(max(proposed.y, screen.minY), screen.maxY - size.height)
        )
    }
}

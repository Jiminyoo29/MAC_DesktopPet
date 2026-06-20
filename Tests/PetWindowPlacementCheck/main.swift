import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
let size = CGSize(width: 190, height: 250)

let defaultOrigin = PetWindowPlacement.resolvedOrigin(
    savedOrigin: nil,
    screen: screen,
    size: size,
    offsetIndex: 0
)
expect(defaultOrigin == CGPoint(x: 750, y: 275), "default origin should place the pet near the right side")

let savedOrigin = PetWindowPlacement.resolvedOrigin(
    savedOrigin: WindowOrigin(x: 100, y: 200),
    screen: screen,
    size: size,
    offsetIndex: 2
)
expect(savedOrigin == CGPoint(x: 100, y: 200), "saved onscreen origin should be reused")

let clampedOrigin = PetWindowPlacement.resolvedOrigin(
    savedOrigin: WindowOrigin(x: 990, y: -30),
    screen: screen,
    size: size,
    offsetIndex: 0
)
expect(clampedOrigin == CGPoint(x: 810, y: 0), "saved offscreen origin should be clamped back onscreen")

print("pet window placement checks passed")

import SwiftUI

// The compiler re-attaches an invocation's own availability attributes to the
// first expanded declaration, so our expansion carries both the fixture's
// availability and the macro's fixed one while Apple's carries only the fixed
// one. Filter availability attributes from both sides; everything else
// (scaffold, body wrapper, arguments) is still compared exactly.
// oam-postprocess: sed -E 's/@available\([^)]*\) ?//g'

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
#Preview("Duration signature") {
    Text("Hello")
}

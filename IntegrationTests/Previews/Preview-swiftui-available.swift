import SwiftUI

// The compiler re-attaches an invocation's own availability attributes (and
// their leading trivia) to the first expanded declaration, so our expansion
// carries both the fixture's availability and the macro's fixed one while
// Apple's carries only the fixed one. Normalize both sides by dropping
// availability attributes, source-comment lines, and blank lines; everything
// else (scaffold, body wrapper, arguments) is still compared exactly.
// oam-postprocess: sed -E '/^\/\/ /d; /^$/d; s/@available\([^)]*\) ?//g'

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, visionOS 1.0, *)
#Preview("Duration signature") {
    Text("Hello")
}

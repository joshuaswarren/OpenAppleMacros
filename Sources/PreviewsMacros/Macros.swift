import OpenAppleMacrosBase
import SwiftDiagnostics

package var all: [Macro.Type] {
    [
        SwiftUIView.self,
        SwiftUIViewGroup_1.self,
        Common.self,
        KitViewMacro.self,
        PreviewCommonGroup.self,
        Previewable.self,
    ]
}

/// Common scaffolding for `#Preview` macros: a unique `PreviewRegistry` type whose
/// `makePreview()` reconstructs the original invocation against
/// `DeveloperToolsSupport.Preview`.
enum PreviewScaffold {
    static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext,
        invocation: String
    ) -> DeclSyntax {
        let location = context.location(of: Syntax(node.poundToken), at: .afterLeadingTrivia, filePathMode: .fileID)!
        let name = context.makeUniqueName("PreviewRegistry")
        return """
        /*BEGIN*/
        nonisolated struct \(name): DeveloperToolsSupport.PreviewRegistry {
            static var fileID: String {
                \(location.file)
            }
            static var line: Int {
                \(location.line)
            }
            static var column: Int {
                \(location.column)
            }

            @MainActor static func makePreview() throws -> DeveloperToolsSupport.Preview {
        \(raw: invocation)
            }
        }
        """
    }

    /// Rewrites `#Preview...` to `DeveloperToolsSupport.Preview...`, dropping any
    /// attributes (e.g. `@available`) attached to the macro declaration.
    static func replaceMacroName(_ node: some FreestandingMacroExpansionSyntax) -> String {
        let text = node.trimmed.description
        let macroName = node.macro.trimmed.text
        guard let hashIndex = text.firstIndex(of: "#"),
              text[hashIndex...].hasPrefix("#" + macroName) else { return text }
        return "DeveloperToolsSupport.Preview" + String(text[text.index(hashIndex, offsetBy: 1 + macroName.count)...])
    }

    /// Re-indents every line of the invocation into the body of `makePreview()`.
    /// Lines keep their relative indentation; only lines created by splitting an
    /// inline closure use fixed indentation.
    static func shift(_ text: String, by spaces: Int) -> String {
        let prefix = String(repeating: " ", count: spaces)
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? $0 : prefix + $0 }
            .joined(separator: "\n")
    }

    static func trimmedWhitespace(_ text: some StringProtocol) -> String {
        String(text.drop(while: { $0 == " " || $0 == "\t" }).reversed().drop(while: { $0 == " " || $0 == "\t" }).reversed())
    }

    /// Emits the invocation for forms using labeled inline closure arguments
    /// (`widget: { ... }, timelineProvider: { ... }`). Every pre-existing line is
    /// re-indented by 8; closures written inline on one line are split onto their
    /// own lines with the content at column 16 and the trailing `}` at column 12.
    static func invocationWithSplitInlineClosures(_ node: some FreestandingMacroExpansionSyntax) -> String {
        shift(splitInlineClosures(replaceMacroName(node)), by: 8)
    }

    private static func splitInlineClosures(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { splitInlineClosures(in: String($0)) }
            .joined(separator: "\n")
    }

    private static func splitInlineClosures(in line: String) -> String {
        let indent = line.prefix(while: { $0 == " " }).count
        var results: [String] = []
        var buffer = ""
        var index = line.startIndex
        var parenDepth = 0
        var braceDepth = 0
        while index < line.endIndex {
            let character = line[index]
            switch character {
            case "(":
                parenDepth += 1
                buffer.append(character)
            case ")":
                parenDepth -= 1
                buffer.append(character)
            case "{":
                // Find the matching close brace on this same line.
                var innerDepth = 1
                var cursor = line.index(after: index)
                var contentEnd = line.index(before: line.endIndex)
                var closed: String.Index?
                while cursor < line.endIndex {
                    let inner = line[cursor]
                    if inner == "{" { innerDepth += 1 }
                    if inner == "}" {
                        innerDepth -= 1
                        if innerDepth == 0 {
                            closed = cursor
                            contentEnd = line.index(before: cursor)
                            break
                        }
                    }
                    cursor = line.index(after: cursor)
                }
                guard parenDepth > 0, braceDepth == 0, let closeIndex = closed,
                      line[line.index(after: index)..<contentEnd].contains(where: { !$0.isWhitespace }) else {
                    if character == "{" { braceDepth += 1 }
                    buffer.append(character)
                    index = line.index(after: index)
                    continue
                }
                buffer.append(character)
                results.append(buffer)
                let content = String(line[line.index(after: index)..<contentEnd])
                results.append(String(repeating: " ", count: indent + 8) + PreviewScaffold.trimmedWhitespace(content))
                buffer = String(repeating: " ", count: indent + 4) + "}"
                index = closeIndex
            case "}":
                if braceDepth > 0 { braceDepth -= 1 }
                buffer.append(character)
            default:
                buffer.append(character)
            }
            index = line.index(after: index)
        }
        results.append(buffer)
        return results.joined(separator: "\n")
    }
}

/// `#Preview { ... }` and `#Preview(name:, traits:, body:)` for SwiftUI views:
/// the body closure is wrapped in a `__b_buildView` helper that erases the
/// `ViewBuilder` result.
struct SwiftUIView: DeclarationMacro {
    static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let text = PreviewScaffold.replaceMacroName(node)
        guard let openBrace = firstTrailingClosureBrace(in: text),
              text.hasSuffix("}") else {
            return [PreviewScaffold.expansion(of: node, in: context, invocation: PreviewScaffold.invocationWithSplitInlineClosures(node))]
        }
        let head = PreviewScaffold.trimmedWhitespace(text[..<openBrace])
        let body = String(text[text.index(after: openBrace)...].dropLast())

        var bodyLines = body.split(separator: "\n", omittingEmptySubsequences: false)
        while let first = bodyLines.first, PreviewScaffold.trimmedWhitespace(first).isEmpty {
            bodyLines.removeFirst()
        }
        while let last = bodyLines.last, PreviewScaffold.trimmedWhitespace(last).isEmpty {
            bodyLines.removeLast()
        }
        let baseIndent = bodyLines.first.map { $0.prefix(while: { $0 == " " }).count } ?? 0
        let reindented = bodyLines.map { line -> String in
            if PreviewScaffold.trimmedWhitespace(line).isEmpty { return "" }
            let indent = line.prefix(while: { $0 == " " }).count
            let target = 16 + (indent - baseIndent)
            return String(repeating: " ", count: max(target, 0)) + line.drop(while: { $0 == " " })
        }.joined(separator: "\n")

        let invocation = [
            PreviewScaffold.shift(head, by: 8) + " {",
            "            func __b_buildView(@SwiftUI.ViewBuilder body: () -> any SwiftUI.View) -> any SwiftUI.View {",
            "                body()",
            "            }",
            "            return __b_buildView {",
            reindented,
            "            }",
            "        }",
        ].joined(separator: "\n")
        return [PreviewScaffold.expansion(of: node, in: context, invocation: invocation)]
    }

    private static func firstTrailingClosureBrace(in text: String) -> String.Index? {
        var depth = 0
        for index in text.indices {
            switch text[index] {
            case "(": depth += 1
            case ")": depth -= 1
            case "{":
                if depth == 0 { return index }
            default: break
            }
        }
        return nil
    }
}

/// `#Preview(name:, traits:, arguments:, body:)` with an argument-carrying body:
/// no ViewBuilder wrapper is inserted.
struct SwiftUIViewGroup_1: DeclarationMacro {
    static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return [PreviewScaffold.expansion(of: node, in: context, invocation: PreviewScaffold.invocationWithSplitInlineClosures(node))]
    }
}

/// WidgetKit `#Preview(as:...)` variants.
struct Common: DeclarationMacro {
    static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return [PreviewScaffold.expansion(of: node, in: context, invocation: PreviewScaffold.invocationWithSplitInlineClosures(node))]
    }
}

/// UIKit `#Preview` variants.
struct KitViewMacro: DeclarationMacro {
    static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return [PreviewScaffold.expansion(of: node, in: context, invocation: PreviewScaffold.invocationWithSplitInlineClosures(node))]
    }
}

/// UIKit `#Preview` with `arguments:` (grouped previews).
struct PreviewCommonGroup: DeclarationMacro {
    static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return [PreviewScaffold.expansion(of: node, in: context, invocation: PreviewScaffold.invocationWithSplitInlineClosures(node))]
    }
}

struct Previewable: PeerMacro {
    static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return []
    }
}

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin

/// Implements @ReconProviderAccessor("name") as a peer macro that emits an
/// extension Recon exposing the attached provider as a typed accessor.
public struct ReconProviderAccessorMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // The type the macro is attached to (class, struct, actor, ...).
        guard let typeName = declaration.asProtocol(NamedDeclSyntax.self)?.name.text else {
            throw ReconMacroError.unsupportedDeclaration
        }

        // The accessor name from @ReconProviderAccessor("some_name"), "some_name" should be a string.
        guard
            let argument = node.arguments?.as(LabeledExprListSyntax.self)?.first?.expression,
            let stringLiteral = argument.as(StringLiteralExprSyntax.self),
            stringLiteral.segments.count == 1,
            case let .stringSegment(segment)? = stringLiteral.segments.first
        else {
            throw ReconMacroError.nameNotAStringLiteral
        }

        let name = segment.content.text

        // Mirror the provider's access level onto the accessor.
        let access = accessLevel(of: declaration)

        return [
        """
        extension Recon {
            \(raw: access)var \(raw: name): \(raw: typeName) {
                guard let provider = provider(\(raw: typeName).self) else {
                    preconditionFailure("\(raw: typeName) isn't registered — call Recon.shared.addRemoteConfigProvider(\(raw: typeName)()) before reading its flags.")
                }
                return provider
            }
        }
        """
        ]
    }

    /// The access-level keyword (with trailing space) to reuse on the generated accessor.
    private static func accessLevel(of declaration: some DeclSyntaxProtocol) -> String {
        declaration.asProtocol(WithModifiersSyntax.self)?.modifiers.lazy.compactMap { modifier -> String? in
            switch modifier.name.tokenKind {
            case .keyword(.public), .keyword(.open): "public "
            case .keyword(.package): "package "
            case .keyword(.fileprivate): "fileprivate "
            case .keyword(.private): "private "
            default: nil
            }
        }.first ?? ""
    }
}

enum ReconMacroError: Error, CustomStringConvertible {
    case unsupportedDeclaration
    case nameNotAStringLiteral

    var description: String {
        switch self {
        case .unsupportedDeclaration:
            "@ReconProviderAccessor can only be attached to a named type."
        case .nameNotAStringLiteral:
            "@ReconProviderAccessor requires a static string literal accessor name."
        }
    }
}

@main
struct ReconMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [ReconProviderAccessorMacro.self]
}

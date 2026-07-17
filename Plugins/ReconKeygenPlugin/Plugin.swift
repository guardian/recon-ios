import Foundation
import PackagePlugin

/// Runs recon-keygen over the target's defaults plists, generating a
/// RemoteConfigKey enum that is compiled into the target.
///
/// The plist's name picks the enum: `<EnumName>.rcf.plist` generates
/// `enum <EnumName>`.
@main
struct ReconKeygenPlugin: BuildToolPlugin {

    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let target = target as? SourceModuleTarget else { return [] }
        let tool = try context.tool(named: "recon-keygen")
        return target.sourceFiles.map(\.url).compactMap {
            Self.command(plist: $0, tool: tool.url, workDirectory: context.pluginWorkDirectoryURL)
        }
    }

    static func enumName(for url: URL) -> String? {
        let fileName = url.lastPathComponent
        let suffix = ".rcf.plist"
        guard fileName.count > suffix.count, fileName.hasSuffix(suffix) else { return nil }
        return String(fileName.dropLast(suffix.count))
    }

    static func command(plist: URL, tool: URL, workDirectory: URL) -> Command? {
        guard let enumName = enumName(for: plist) else { return nil }
        let output = workDirectory.appending(path: "\(enumName)-generated.swift")
        return .buildCommand(
            displayName: "Recon: generating \(enumName) from \(plist.lastPathComponent)",
            executable: tool,
            arguments: [plist.path, output.path, enumName],
            inputFiles: [plist],
            outputFiles: [output]
        )
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension ReconKeygenPlugin: XcodeBuildToolPlugin {

    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        let tool = try context.tool(named: "recon-keygen")
        return target.inputFiles.map(\.url).compactMap {
            Self.command(plist: $0, tool: tool.url, workDirectory: context.pluginWorkDirectoryURL)
        }
    }
}
#endif

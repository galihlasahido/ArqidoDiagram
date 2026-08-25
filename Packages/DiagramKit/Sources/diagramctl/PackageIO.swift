import Foundation
import DiagramModel
import DiagramPersistence

/// Reads/writes a `.diagram` package as a plain filesystem path — the CLI
/// has no `NSDocument`, so it drives `PackageWriter`/`PackageReader`
/// directly via `FileWrapper(url:)`/`FileWrapper.write(to:)`, the same
/// primitives `NSDocument` itself uses under the hood.
enum PackageIO {
    static func read(from path: String) throws -> DiagramDocumentModel {
        let url = URL(fileURLWithPath: path)
        let wrapper = try FileWrapper(url: url)
        return try PackageReader.documentModel(from: wrapper)
    }

    static func write(_ model: DiagramDocumentModel, to path: String) throws {
        let url = URL(fileURLWithPath: path)
        let wrapper = try PackageWriter.fileWrapper(for: model)
        try wrapper.write(to: url, options: [.atomic], originalContentsURL: nil)
    }
}

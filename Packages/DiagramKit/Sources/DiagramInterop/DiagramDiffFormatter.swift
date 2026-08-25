import DiagramModel

/// Spec §19/§30/§34 "Diagram diff" / "Compare environments": named, not
/// just counted — the worked examples in both sections show real object
/// names ("+ Redis", "- Legacy API"), not "3 nodes added". Lives in
/// DiagramInterop (not the CLI target) so it's unit-testable and reusable
/// by any future in-app "Compare with File" feature, not just
/// `diagramctl diff`/`compare-env`.
public enum DiagramDiffFormatter {
    public static func diffLines(from oldModel: DiagramDocumentModel, to newModel: DiagramDocumentModel) -> [String] {
        var lines: [String] = []
        let oldPagesByName = Dictionary(uniqueKeysWithValues: oldModel.pageOrder.compactMap { id -> (String, DiagramPage)? in
            guard let page = oldModel.pages[id] else { return nil }
            return (page.name, page)
        })
        let newPagesByName = Dictionary(uniqueKeysWithValues: newModel.pageOrder.compactMap { id -> (String, DiagramPage)? in
            guard let page = newModel.pages[id] else { return nil }
            return (page.name, page)
        })

        for pageName in Set(newPagesByName.keys).subtracting(oldPagesByName.keys).sorted() {
            lines.append("+ Page: \(pageName)")
        }
        for pageName in Set(oldPagesByName.keys).subtracting(newPagesByName.keys).sorted() {
            lines.append("- Page: \(pageName)")
        }

        for pageName in Set(oldPagesByName.keys).intersection(newPagesByName.keys).sorted() {
            guard let oldPage = oldPagesByName[pageName], let newPage = newPagesByName[pageName] else { continue }
            lines.append(contentsOf: pageDiffLines(from: oldPage, to: newPage))
        }
        return lines
    }

    /// The lower-level half `compare-env` reuses directly — it isn't
    /// comparing two *pages* so much as two node subsets, but the label-set
    /// diff logic is identical.
    public static func nodeDiffLines(from oldNodes: [String: DiagramNode], to newNodes: [String: DiagramNode]) -> [String] {
        var lines: [String] = []
        for name in Set(newNodes.keys).subtracting(oldNodes.keys).sorted() {
            lines.append("+ \(name)")
        }
        for name in Set(oldNodes.keys).subtracting(newNodes.keys).sorted() {
            lines.append("- \(name)")
        }
        for name in Set(oldNodes.keys).intersection(newNodes.keys).sorted() {
            guard let oldNode = oldNodes[name], let newNode = newNodes[name],
                  oldNode.metadata != newNode.metadata || oldNode.type != newNode.type else { continue }
            lines.append("~ \(name) configuration changed")
        }
        return lines
    }

    private static func pageDiffLines(from oldPage: DiagramPage, to newPage: DiagramPage) -> [String] {
        func label(_ node: DiagramNode) -> String {
            node.text?.string.isEmpty == false ? node.text!.string : node.type.rawValue
        }
        let oldByLabel = Dictionary(oldPage.nodes.values.map { (label($0), $0) }, uniquingKeysWith: { first, _ in first })
        let newByLabel = Dictionary(newPage.nodes.values.map { (label($0), $0) }, uniquingKeysWith: { first, _ in first })
        return nodeDiffLines(from: oldByLabel, to: newByLabel)
    }
}

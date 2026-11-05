/// What every work is held to as it is raised, each family's work
/// modelled whole at each level, its yard and stores, its lamps and banners
/// its own; and how one mesh is laid over another.
enum Estate {
    /// The most triangles a work may come to.
    static let ceiling = 2950

    /// One mesh after another, each one's far work before either's fine.
    static func layered(_ a: Mesh, _ b: Mesh) -> Mesh {
        guard !b.isEmpty else { return a }
        var whole = Mesh()
        whole.vertices = a.vertices + b.vertices
        let offset = UInt32(a.vertices.count)
        let aCoarse = a.indices[0..<a.coarseIndexCount], aFine = a.indices[a.coarseIndexCount...]
        let bCoarse = b.indices[0..<b.coarseIndexCount].map { $0 + offset }
        let bFine = b.indices[b.coarseIndexCount...].map { $0 + offset }
        whole.indices = Array(aCoarse) + bCoarse + Array(aFine) + bFine
        if !aFine.isEmpty || !bFine.isEmpty { whole.fineFrom = aCoarse.count + bCoarse.count }
        return whole
    }
}

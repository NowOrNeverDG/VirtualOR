//
//  ORSceneModel.swift
//  VirtualOR
//
//  Created by Ge Ding on 2025/10/7.
//

import SwiftUI
import RealityKit
import RealityKitContent

// MARK: - ORNodeKey

/// A key that uniquely identifies an entity by a path of child names.
/// Accepts string literal like "Room/Desk/Drawer" and turns into ["Room","Desk","Drawer"].
public struct ORNodeKey: Hashable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let path: [String]
    public init(_ path: [String]) { self.path = path }
    public init(stringLiteral value: StringLiteralType) {
        self.path = value.split(separator: "/").map(String.init)
    }
    public var description: String { path.joined(separator: "/") }
}

// MARK: - ORScene

/// A lightweight scene manager that wraps common RealityKit operations:
/// - Asynchronous scene loading & mounting
/// - Path-based entity resolve (with cache)
/// - Show/Hide (recursive)
/// - Selection & highlight (restore materials on clear)
/// - Move/Rotate (instant & animated)
/// - Collision & hit-testing preparation
/// - Named animation playback (loop or once)
/// - Per-node tap handlers (register with `onTap`)
///
/// The class is @MainActor since RealityKit entity graph is UI/scene-thread bound.
@MainActor
final class ORScene: ObservableObject {

    // MARK: Core State

    /// The root entity of the loaded scene (e.g., the entire room model).
    private(set) var root: Entity?

    /// A simple cache from ORNodeKey to resolved Entity for faster subsequent lookups.
    private var cache: [ORNodeKey: Entity] = [:]

    /// The key of the currently selected node (single-selection).
    @Published private(set) var selectedKey: ORNodeKey?

    /// Original materials of selected entities to restore when clearing selection.
    private var selectedOriginalMaterials: [Entity.ID: [any RealityKit.Material]] = [:]

    /// Registered tap handlers per node key. Handlers get the resolved entity.
    private var tapHandlers: [ORNodeKey: (Entity) -> Void] = [:]

    /// Indicates whether the scene (USDZ) is fully loaded and mounted in the view.
    @Published var isLoaded = false

    // MARK: Load & Mount

    /// Loads an Entity (USDZ) asynchronously and adds it into the given RealityView content.
    ///
    /// - Parameters:
    ///   - content: The `RealityViewContent` to mount the entity to.
    ///   - resourceName: The USDZ resource name (without extension) bundled in `bundle`.
    ///   - bundle: The bundle that contains the USDZ. Defaults to `realityKitContentBundle`.
    ///   - position: Initial world position for the loaded root entity.
    func load(into content: RealityViewContent,
              resourceName: String,
              bundle: Bundle = realityKitContentBundle,
              at position: SIMD3<Float> = [0, 0, -2]) async {
        do {
            let entity = try await Entity(named: resourceName, in: bundle)
            entity.position = position
            content.add(entity)
            root = entity
            cache.removeAll()
            isLoaded = true
        } catch {
            isLoaded = false
            assertionFailure("Failed to load \(resourceName): \(error)")
        }
    }

    // MARK: Resolve

    /// Resolves an entity for the given key by descending the child path from `root`.
    /// Results are cached to avoid repeated tree traversal.
    func entity(for key: ORNodeKey) -> Entity? {
        if let cached = cache[key] { return cached }
        guard let root, isLoaded else { return nil }
        guard let found = findByPath(key.path, from: root) else { return nil }
        cache[key] = found
        return found
    }

    /// Invalidates a single cached resolve result.
    func invalidate(_ key: ORNodeKey) { cache.removeValue(forKey: key) }

    /// Invalidates the entire resolve cache (e.g., after dynamic hierarchy changes).
    func invalidateAll() { cache.removeAll() }

    // MARK: Show / Hide

    /// Shows the entity at `key`. If `recursive` is true, all descendants are shown.
    func show(_ key: ORNodeKey, recursive: Bool = true) { setEnabled(key, true, recursive: recursive) }

    /// Hides the entity at `key`. If `recursive` is true, all descendants are hidden.
    func hide(_ key: ORNodeKey, recursive: Bool = true) { setEnabled(key, false, recursive: recursive) }

    private func setEnabled(_ key: ORNodeKey, _ flag: Bool, recursive: Bool) {
        guard let e = entity(for: key) else { return }
        if recursive { e.visit { $0.isEnabled = flag } }
        else { e.isEnabled = flag }
    }

    // MARK: Selection & Highlight

    /// Selects and highlights the entity at `key`. Previous selection is cleared (single-select).
    /// Highlight is implemented via emissive SimpleMaterial; customize as needed.
    func select(_ key: ORNodeKey, highlightColor: UIColor = .systemYellow) {
        guard let e = entity(for: key) else { return }
        clearSelection()

        if var mc = e.components[ModelComponent.self] {
            selectedOriginalMaterials[e.id] = mc.materials

            var mat = SimpleMaterial(color: .white, isMetallic: false)
            mc.materials = [mat]
            e.components.set(mc)
        }
        selectedKey = key
    }

    /// Clears the current selection and restores original materials.
    func clearSelection() {
        guard let key = selectedKey,
              let e = entity(for: key),
              var mc = e.components[ModelComponent.self],
              let originals = selectedOriginalMaterials[e.id]
        else {
            selectedKey = nil
            return
        }
        mc.materials = originals
        e.components.set(mc)
        selectedOriginalMaterials.removeValue(forKey: e.id)
        selectedKey = nil
    }

    /// Toggles selection of a node.
    func toggleSelect(_ key: ORNodeKey) {
        if selectedKey == key { clearSelection() } else { select(key) }
    }

    // MARK: Transform (Instant)

    /// Translates the entity at `key` by `delta` instantly.
    func translate(_ key: ORNodeKey, by delta: SIMD3<Float>) {
        entity(for: key)?.position += delta
    }

    /// Sets the position of the entity at `key` instantly.
    func move(_ key: ORNodeKey, to pos: SIMD3<Float>) {
        entity(for: key)?.position = pos
    }

    /// Rotates the entity around `axis` by `angle` (radians) instantly.
    /// The rotation is applied to the nearest ancestor that carries a ModelComponent
    /// to yield more natural pivot behavior for meshes.
    func rotate(_ key: ORNodeKey, axis: SIMD3<Float>, angle: Float) {
        guard let e = entity(for: key) else { return }
        let pivot = nearestModelEntity(from: e)
        let q = simd_quatf(angle: angle, axis: normalize(axis))
        pivot.transform.rotation = simd_mul(q, pivot.transform.rotation)
    }

    // MARK: Transform (Animated)

    /// Animates the entity at `key` to `pos` with a smooth timing function.
    /// - Note: Position is relative to the entity’s parent when using `move(to:relativeTo:duration:)`.
    func move(_ key: ORNodeKey, to pos: SIMD3<Float>, duration: TimeInterval, timing: RealityKit.AnimationTimingFunction = .easeInOut) {
        guard let e = entity(for: key) else { return }
        e.move(to: Transform(translation: pos), relativeTo: e.parent, duration: duration, timingFunction: timing)
    }

    /// Animates rotation by applying a new quaternion to the nearest model ancestor.
    /// - Parameters:
    ///   - axis: The axis to rotate around (will be normalized).
    ///   - angle: The angle in radians.
    ///   - duration: Animation duration in seconds.
    ///   - timing: Easing function (default .easeInOut).
    func rotate(_ key: ORNodeKey, axis: SIMD3<Float>, angle: Float, duration: TimeInterval, timing: RealityKit.AnimationTimingFunction = .easeInOut) {
        guard let e = entity(for: key) else { return }
        let pivot = nearestModelEntity(from: e)
        var t = pivot.transform
        let q = simd_quatf(angle: angle, axis: normalize(axis))
        t.rotation = simd_mul(q, t.rotation)
        pivot.move(to: t, relativeTo: pivot.parent, duration: duration, timingFunction: timing)
    }

    // MARK: Materials

    /// Replaces materials of the entity at `key` with a simple colored material.
    func setColor(_ key: ORNodeKey, _ color: UIColor) {
        guard let e = entity(for: key), var mc = e.components[ModelComponent.self] else { return }
        mc.materials = [SimpleMaterial(color: color, isMetallic: false)]
        e.components.set(mc)
    }

    // MARK: Collision

    /// Ensures collision shapes are generated for the entity at `key`, so it can receive hits/taps.
    func enableCollision(_ key: ORNodeKey, recursive: Bool = true) {
        entity(for: key)?.generateCollisionShapes(recursive: recursive)
    }

    // MARK: Animations

    /// Plays a named animation clip attached to the entity at `key`.
    /// The clip must exist in `entity.availableAnimations` (typically authored in DCC and exported to USDZ).
    ///
    /// - Parameters:
    ///   - key: Node key whose entity carries the animation clip.
    ///   - name: Name of the animation clip (e.g., "Open", "Close").
    ///   - loop: If true, repeats indefinitely; otherwise plays once.
    ///   - transitionDuration: Cross-fade duration when blending from current pose (seconds).
    func playAnimation(_ key: ORNodeKey, named name: String, loop: Bool = true, transitionDuration: TimeInterval = 0.15) {
        guard let e = entity(for: key),
              let clip = e.availableAnimations.first(where: { $0.name == name }) else { return }
        e.playAnimation(loop ? clip.repeat() : clip, transitionDuration: transitionDuration)
    }

    /// Stops all currently playing animations on the entity at `key`.
    func stopAnimations(_ key: ORNodeKey) {
        entity(for: key)?.stopAllAnimations()
    }

    /// Utility to inspect what clips are present on the entity at `key` (debug logging).
    func logAvailableAnimations(_ key: ORNodeKey) {
        guard let e = entity(for: key) else { return }
        let names = e.availableAnimations.map(\.name)
        print("🎞️ [\(key)] clips:", names)
    }

    // MARK: Tap Routing

    /// Registers a tap handler for `key`. The handler receives the resolved entity.
    /// Generates collision shapes automatically so the entity becomes hittable.
    func onTap(_ key: ORNodeKey, perform: @escaping (Entity) -> Void) {
        tapHandlers[key] = perform
        if let e = entity(for: key) { e.generateCollisionShapes(recursive: true) }
    }

    /// Should be called by your RealityView gesture layer upon a targeted tap.
    /// Finds the best (longest-path) matching handler and invokes it.
    func handleTap(on tappedEntity: Entity) {
        guard let root else { return }
        let path = pathFromRoot(to: tappedEntity, root: root)
        let candidates = tapHandlers.keys
            .filter { path.ends(with: $0.path) }
            .sorted { $0.path.count > $1.path.count } // prefer most specific
        if let key = candidates.first,
           let e = entity(for: key),
           let handler = tapHandlers[key] {
            handler(e)
        }
    }

    // MARK: Helpers

    /// Builds a name path from `root` to `node` (inclusive).
    private func pathFromRoot(to node: Entity, root: Entity) -> [String] {
        var names: [String] = []
        var cur: Entity? = node
        while let c = cur {
            names.append(c.name)
            if c == root { break }
            cur = c.parent
        }
        return names.reversed()
    }
}

// MARK: - Free Utilities

private extension Entity {
    /// Preorder traversal visitor.
    func visit(_ f: (Entity) -> Void) {
        f(self)
        for child in children { child.visit(f) }
    }
}

/// Finds an entity by strictly matching child names on each path segment.
func findByPath(_ segments: [String], from root: Entity) -> Entity? {
    var cur: Entity? = root
    for seg in segments {
        cur = cur?.children.first { $0.name == seg }
        if cur == nil { return nil }
    }
    return cur
}

/// Returns the nearest ancestor (including self) that has a ModelComponent.
/// Using this entity as the pivot usually yields more natural rotation for meshes.
func nearestModelEntity(from e: Entity) -> Entity {
    var cur: Entity? = e
    while let node = cur {
        if node.components[ModelComponent.self] != nil { return node }
        cur = node.parent
    }
    return e
}

private extension Array where Element == String {
    /// Returns true if the receiver ends with `suffix` (element-wise).
    func ends(with suffix: [String]) -> Bool {
        guard suffix.count <= count else { return false }
        return zip(suffix.reversed(), self.suffix(suffix.count).reversed()).allSatisfy(==)
    }
}

/// How the user orders each wheel: pinned options first, then optionally the last one used, then
/// optionally the most used. Options are keyed by `WheelOption.id`, like `WheelVisibility`.
public struct WheelUsage: Sendable, Equatable, Codable {
    /// Pinned option IDs, in the order they were pinned.
    public private(set) var pinned: [String]
    /// The option last used on each wheel (`convert`, `tools`, `actions`).
    public private(set) var lastUsed: [String: String]
    public private(set) var counts: [String: Int]
    /// Puts the wheel's last choice right after the pins (on by default).
    public var lastUsedFirst: Bool
    /// Orders the rest by how often each was used (off by default, so petals stay where they are).
    public var ordersByFrequency: Bool

    public init(
        pinned: [String] = [],
        lastUsed: [String: String] = [:],
        counts: [String: Int] = [:],
        lastUsedFirst: Bool = true,
        ordersByFrequency: Bool = false
    ) {
        self.pinned = pinned
        self.lastUsed = lastUsed
        self.counts = counts
        self.lastUsedFirst = lastUsedFirst
        self.ordersByFrequency = ordersByFrequency
    }

    public static let standard = WheelUsage()

    public func isPinned(_ option: WheelOption) -> Bool { pinned.contains(option.id) }

    public mutating func setPinned(_ option: WheelOption, _ isPinned: Bool) {
        pinned.removeAll { $0 == option.id }
        if isPinned { pinned.append(option.id) }
    }

    /// Records one use of `option` on its wheel.
    public mutating func record(_ option: WheelOption) {
        lastUsed[Self.key(Self.wheel(of: option))] = option.id
        counts[option.id, default: 0] += 1
    }

    /// `options` reordered: pins in pin order, then the last used, then by use count or as given.
    /// Ties keep their original order, so nothing moves without a reason.
    public func ordered(_ options: [WheelOption], on wheel: WheelKind) -> [WheelOption] {
        let indexed = Array(options.enumerated())
        let recent = lastUsedFirst ? lastUsed[Self.key(wheel)] : nil
        func rank(_ option: WheelOption) -> (group: Int, order: Int) {
            if let pin = pinned.firstIndex(of: option.id) { return (0, pin) }
            if option.id == recent { return (1, 0) }
            return (2, ordersByFrequency ? -(counts[option.id] ?? 0) : 0)
        }
        return indexed.sorted { lhs, rhs in
            let (left, right) = (rank(lhs.element), rank(rhs.element))
            return left != right ? left < right : lhs.offset < rhs.offset
        }.map(\.element)
    }

    static func wheel(of option: WheelOption) -> WheelKind {
        switch option.kind {
        case .format: .convert
        case .tool: .tools
        case .action: .actions
        case .recipe: .tools
        }
    }

    private static func key(_ wheel: WheelKind) -> String {
        switch wheel {
        case .convert: "convert"
        case .tools: "tools"
        case .actions: "actions"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case pinned, lastUsed, counts, lastUsedFirst, ordersByFrequency
    }

    /// Missing fields fall back to the defaults, so older or partial stored values still load.
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            pinned: try values.decodeIfPresent([String].self, forKey: .pinned) ?? [],
            lastUsed: try values.decodeIfPresent([String: String].self, forKey: .lastUsed) ?? [:],
            counts: try values.decodeIfPresent([String: Int].self, forKey: .counts) ?? [:],
            lastUsedFirst: try values.decodeIfPresent(Bool.self, forKey: .lastUsedFirst) ?? true,
            ordersByFrequency: try values.decodeIfPresent(Bool.self, forKey: .ordersByFrequency) ?? false
        )
    }
}

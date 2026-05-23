import Foundation

struct RemoteSlot: Equatable {
    let slot: Int
    let content: CapturedContent
    let template: String?
    let sourceAppName: String?
    let updatedAt: Date
    let updatedBy: String
}

enum SlotFileFormat {
    static let schemaVersion = 1

    static func write(item: ClipboardItem, slot: Int, folder: URL, deviceID: String) throws {
        switch item.content {
        case .text(let text):
            try writeTextSlot(
                text: text,
                kind: "text",
                template: item.pinnedTemplate,
                sourceAppName: item.sourceAppName,
                slot: slot,
                folder: folder,
                deviceID: deviceID
            )
        case .fileURLs(let paths):
            try writeTextSlot(
                text: paths.joined(separator: "\n"),
                kind: "fileURL",
                template: nil,
                sourceAppName: item.sourceAppName,
                slot: slot,
                folder: folder,
                deviceID: deviceID
            )
        case .image(let data, _):
            try writeImageSlot(
                pngData: data,
                sourceAppName: item.sourceAppName,
                slot: slot,
                folder: folder,
                deviceID: deviceID
            )
        }
    }

    static func remove(slot: Int, folder: URL) {
        for name in ["slot-\(slot).json", "slot-\(slot).meta.json", "slot-\(slot).png"] {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
    }

    static func readAll(from folder: URL) -> [RemoteSlot] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        ) else { return [] }
        var seenSlots = Set<Int>()
        var snapshots: [RemoteSlot] = []
        for url in entries {
            guard let slot = parseSlotNumber(filename: url.lastPathComponent),
                  !seenSlots.contains(slot),
                  let snapshot = readSlot(slot: slot, folder: folder) else { continue }
            seenSlots.insert(slot)
            snapshots.append(snapshot)
        }
        return snapshots.sorted { $0.slot < $1.slot }
    }

    // MARK: - private

    private static func writeTextSlot(
        text: String,
        kind: String,
        template: String?,
        sourceAppName: String?,
        slot: Int,
        folder: URL,
        deviceID: String
    ) throws {
        let payload = SlotTextPayload(
            schemaVersion: schemaVersion,
            slot: slot,
            kind: kind,
            text: text,
            template: template,
            sourceAppName: sourceAppName,
            updatedAt: isoFormatter.string(from: Date()),
            updatedBy: deviceID
        )
        try writeAtomic(payload, to: folder.appendingPathComponent("slot-\(slot).json"))
        try? FileManager.default.removeItem(at: folder.appendingPathComponent("slot-\(slot).meta.json"))
        try? FileManager.default.removeItem(at: folder.appendingPathComponent("slot-\(slot).png"))
    }

    private static func writeImageSlot(
        pngData: Data,
        sourceAppName: String?,
        slot: Int,
        folder: URL,
        deviceID: String
    ) throws {
        let pngName = "slot-\(slot).png"
        let pngURL = folder.appendingPathComponent(pngName)
        try pngData.write(to: pngURL, options: .atomic)

        let payload = SlotImagePayload(
            schemaVersion: schemaVersion,
            slot: slot,
            kind: "image",
            imageFile: pngName,
            imageBytes: pngData.count,
            sourceAppName: sourceAppName,
            updatedAt: isoFormatter.string(from: Date()),
            updatedBy: deviceID
        )
        try writeAtomic(payload, to: folder.appendingPathComponent("slot-\(slot).meta.json"))
        try? FileManager.default.removeItem(at: folder.appendingPathComponent("slot-\(slot).json"))
    }

    private static func readSlot(slot: Int, folder: URL) -> RemoteSlot? {
        let metaURL = folder.appendingPathComponent("slot-\(slot).meta.json")
        if let data = try? Data(contentsOf: metaURL),
           let payload = try? JSONDecoder().decode(SlotImagePayload.self, from: data),
           let date = isoFormatter.date(from: payload.updatedAt),
           let pngData = try? Data(contentsOf: folder.appendingPathComponent(payload.imageFile))
        {
            return RemoteSlot(
                slot: slot,
                content: .image(data: pngData, thumbnail: Data()),
                template: nil,
                sourceAppName: payload.sourceAppName,
                updatedAt: date,
                updatedBy: payload.updatedBy
            )
        }
        let textURL = folder.appendingPathComponent("slot-\(slot).json")
        if let data = try? Data(contentsOf: textURL),
           let payload = try? JSONDecoder().decode(SlotTextPayload.self, from: data),
           let date = isoFormatter.date(from: payload.updatedAt)
        {
            let content: CapturedContent
            if payload.kind == "fileURL" {
                let paths = payload.text.split(separator: "\n").map(String.init)
                content = .fileURLs(paths)
            } else {
                content = .text(payload.text)
            }
            return RemoteSlot(
                slot: slot,
                content: content,
                template: payload.template,
                sourceAppName: payload.sourceAppName,
                updatedAt: date,
                updatedBy: payload.updatedBy
            )
        }
        return nil
    }

    private static func parseSlotNumber(filename: String) -> Int? {
        guard filename.hasPrefix("slot-") else { return nil }
        let tail = filename.dropFirst("slot-".count)
        guard let dot = tail.firstIndex(of: ".") else { return nil }
        return Int(tail[..<dot])
    }

    private static func writeAtomic<T: Encodable>(_ payload: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        try data.write(to: url, options: .atomic)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

private struct SlotTextPayload: Codable {
    let schemaVersion: Int
    let slot: Int
    let kind: String
    let text: String
    let template: String?
    let sourceAppName: String?
    let updatedAt: String
    let updatedBy: String
}

private struct SlotImagePayload: Codable {
    let schemaVersion: Int
    let slot: Int
    let kind: String
    let imageFile: String
    let imageBytes: Int
    let sourceAppName: String?
    let updatedAt: String
    let updatedBy: String
}

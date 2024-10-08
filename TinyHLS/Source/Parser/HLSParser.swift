import Foundation

/// Constants representing HLS tags used in the playlist.
private struct HLSConstants {
    static let extM3U = "#EXTM3U"
    static let extXVersion = "#EXT-X-VERSION"
    static let extXStreamInf = "#EXT-X-STREAM-INF"
    static let extInf = "#EXTINF"
    static let extXEndList = "#EXT-X-ENDLIST"
}

/// Enumeration of possible errors that can occur while parsing HLS playlists.
public enum HLSParserError: Error {
    case invalidFormat
    case missingVersion
    case missingURI
    case invalidAttribute
    case missingTargetDuration
}

/// Represents an HLS master playlist.
public struct HLSMasterPlaylist {
    let version: Int
    let variants: [HLSVariantStream]
}

/// Represents a variant stream in an HLS master playlist.
public struct HLSVariantStream {
    let bandwidth: Int
    let codecs: String
    let resolution: (width: Int, height: Int)?
    let frameRate: Double?
    let videoRange: String?
    let uri: String
}

/// Represents an HLS media playlist.
public struct HLSMediaPlaylist {
    let version: Int
    let targetDuration: Int
    let segments: [HLSSegment]
}

/// Represents a segment in an HLS media playlist.
public struct HLSSegment {
    let duration: Double
    let uri: String
}

/// Class responsible for parsing HLS playlists.
class HLSParser {
    /// Parses an HLS master playlist from the given data.
    /// - Parameter data: The data representing the HLS master playlist.
    /// - Throws: `HLSParserError` if parsing fails.
    /// - Returns: An `HLSMasterPlaylist` object representing the parsed playlist.
    func parseMasterPlaylist(data: Data) throws -> HLSMasterPlaylist {
        guard let content = String(data: data, encoding: .utf8) else {
            throw HLSParserError.invalidFormat
        }
        var version: Int?
        var variants = [HLSVariantStream]()
        let lines = content.components(separatedBy: .newlines)
        var index = 0
        while index < lines.count {
            let line = lines[index]
            if line.hasPrefix(HLSConstants.extXVersion) {
                let versionString = line.replacingOccurrences(of: "\(HLSConstants.extXVersion):", with: "")
                if let ver = Int(versionString) { version = ver }
            } else if line.hasPrefix(HLSConstants.extXStreamInf) {
                let attributesString = line.replacingOccurrences(of: "\(HLSConstants.extXStreamInf):", with: "")
                let attributes = try parseAttributes(attributesString)
                guard let uriLine = lines[safe: index + 1] else {
                    throw HLSParserError.missingURI
                }
                let variant = try createVariantStream(from: attributes, uri: uriLine)
                variants.append(variant)
                index += 1
            }
            index += 1
        }
        guard let playlistVersion = version else {
            throw HLSParserError.missingVersion
        }
        return HLSMasterPlaylist(version: playlistVersion, variants: variants)
    }

    /// Parses an HLS media playlist from the given data.
    /// - Parameter data: The data representing the HLS media playlist.
    /// - Throws: `HLSParserError` if parsing fails.
    /// - Returns: An `HLSMediaPlaylist` object representing the parsed playlist.
    func parseMediaPlaylist(data: Data) throws -> HLSMediaPlaylist {
        guard let content = String(data: data, encoding: .utf8) else {
            throw HLSParserError.invalidFormat
        }
        var version: Int?
        var targetDuration: Int?
        var segments = [HLSSegment]()
        let lines = content.components(separatedBy: .newlines)
        var index = 0
        while index < lines.count {
            let line = lines[index]
            if line.hasPrefix(HLSConstants.extXVersion) {
                let versionString = line.replacingOccurrences(of: "\(HLSConstants.extXVersion):", with: "")
                if let ver = Int(versionString) { version = ver }
            } else if line.hasPrefix("#EXT-X-TARGETDURATION") {
                let durationString = line.replacingOccurrences(of: "#EXT-X-TARGETDURATION:", with: "")
                if let duration = Int(durationString) { targetDuration = duration }
            } else if line.hasPrefix(HLSConstants.extInf) {
                let durationString = line.replacingOccurrences(of: "\(HLSConstants.extInf):", with: "")
                    .components(separatedBy: ",")[0]
                guard let duration = Double(durationString) else {
                    throw HLSParserError.invalidFormat
                }
                guard let uriLine = lines[safe: index + 1] else {
                    throw HLSParserError.missingURI
                }
                let segment = HLSSegment(duration: duration, uri: uriLine)
                segments.append(segment)
                index += 1
            }
            index += 1
        }
        guard let playlistVersion = version else {
            throw HLSParserError.missingVersion
        }
        guard let playlistTargetDuration = targetDuration else {
            throw HLSParserError.missingTargetDuration
        }
        return HLSMediaPlaylist(version: playlistVersion, targetDuration: playlistTargetDuration, segments: segments)
    }

    /// Parses a string of attributes into a dictionary.
    /// - Parameter string: The string containing key-value pairs of attributes.
    /// - Throws: `HLSParserError` if parsing fails.
    /// - Returns: A dictionary of attribute key-value pairs.
    private func parseAttributes(_ string: String) throws -> [String: String] {
        var attributes = [String: String]()
        var isInsideQuotes = false
        var key = ""
        var value = ""
        var current = ""
        var parsingKey = true

        for character in string {
            if character == "\"" {
                isInsideQuotes.toggle()
                current.append(character)
            } else if character == "=" && !isInsideQuotes && parsingKey {
                key = current.trimmingCharacters(in: .whitespaces)
                current = ""
                parsingKey = false
            } else if character == "," && !isInsideQuotes && !parsingKey {
                value = current.trimmingCharacters(in: .whitespaces)
                if value.hasPrefix("\""), value.hasSuffix("\"") {
                    value = String(value.dropFirst().dropLast())
                }
                attributes[key] = value
                current = ""
                parsingKey = true
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty {
            value = current.trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\""), value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
            }
            attributes[key] = value
        }
        return attributes
    }

    /// Creates a `HLSVariantStream` object from parsed attributes and URI.
    /// - Parameters:
    ///   - attributes: A dictionary of attributes for the variant stream.
    ///   - uri: The URI of the variant stream.
    /// - Throws: `HLSParserError` if required attributes are missing.
    /// - Returns: An `HLSVariantStream` object representing the parsed variant stream.
    private func createVariantStream(from attributes: [String: String], uri: String) throws -> HLSVariantStream {
        guard let bandwidthString = attributes["BANDWIDTH"], let bandwidth = Int(bandwidthString),
              let codecs = attributes["CODECS"]
        else {
            throw HLSParserError.invalidAttribute
        }
        var resolution: (width: Int, height: Int)?
        if let resString = attributes["RESOLUTION"] {
            let dims = resString.split(separator: "x")
            if dims.count == 2, let width = Int(dims[0]), let height = Int(dims[1]) {
                resolution = (width, height)
            }
        }
        var frameRate: Double?
        if let frameRateString = attributes["FRAME-RATE"] {
            frameRate = Double(frameRateString)
        }
        let videoRange = attributes["VIDEO-RANGE"]
        return HLSVariantStream(
            bandwidth: bandwidth,
            codecs: codecs,
            resolution: resolution,
            frameRate: frameRate,
            videoRange: videoRange,
            uri: uri
        )
    }
}

/// Extension to safely access elements in a collection.
extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

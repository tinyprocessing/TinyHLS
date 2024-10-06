import SwiftUI

@main
struct TinyHLSApp: App {
    let network: HLSNetworkHandler
    let parser: HLSParser
    let buffer: HLSBufferManager

    init() {
        network = HLSNetworkHandler()
        parser = HLSParser()
        buffer = HLSBufferManager(maxBufferSize: 16)
    }

    var body: some Scene {
        WindowGroup {
            Button("Download file", action: {
                Task {
                    await downloadAndProcessFile()
                }
            })
        }
    }

    private func downloadAndProcessFile() async {
        do {
            let masterPlaylistData = try await downloadFile(urlString: Constants.streamPath)
            let parsedMasterPlaylist = try parseMasterPlaylist(data: masterPlaylistData)
            let selectedVariant = try selectVariant(from: parsedMasterPlaylist)
            let variantURL = try createURL(from: Constants.domain + selectedVariant.uri)
            let playlistData = try await network.downloadM3U8File(url: variantURL)
            let parsedPlaylist = try parser.parseMediaPlaylist(data: playlistData)
            let downloadedChunks = try await downloadChunks(from: parsedPlaylist.segments)
            processChunks(downloadedChunks)
        } catch let error as PlayerError {
            handleError(error)
        } catch {
            handleError(.unexpectedError(error))
        }
    }

    private func downloadFile(urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw PlayerError.invalidURL
        }
        return try await network.downloadM3U8File(url: url)
    }

    private func parseMasterPlaylist(data: Data) throws -> HLSMasterPlaylist {
        return try parser.parseMasterPlaylist(data: data)
    }

    private func selectVariant(from playlist: HLSMasterPlaylist) throws -> HLSVariantStream {
        guard let selectedVariant = playlist.variants
            .first(where: { $0.resolution != nil && $0.bandwidth == Config.targetBandwidth })
        else {
            throw PlayerError.noVariantFound
        }
        return selectedVariant
    }

    private func createURL(from urlString: String) throws -> URL {
        guard let url = URL(string: urlString) else {
            throw PlayerError.invalidURL
        }
        return url
    }

    private func downloadChunks(from segments: [HLSSegment]) async throws -> [Data] {
        let chunkedSegments = Utils.chunkArray(segments, chunkSize: 3)
        guard let firstGroup = chunkedSegments.first else {
            throw PlayerError.noSegmentsFound
        }
        return try await network
            .downloadTSFiles(urls: firstGroup.compactMap { try? createURL(from: Constants.domain + $0.uri) })
    }

    private func processChunks(_ chunks: [Data]) {
        chunks.forEach { buffer.addSegment($0) }
        print(buffer.isBufferReady())
        print(buffer.getBufferStatus())
        print(buffer.getCurrentSegment())
    }

    private func handleError(_ error: PlayerError) {
        switch error {
        case .networkError(let urlError):
            print("Error downloading file: \(urlError.localizedDescription)")
        case .parserError(let parserError):
            print("Error parsing file: \(parserError)")
        case .playerError(let playerError):
            print("Player error: \(playerError)")
        case .unexpectedError(let error):
            print("Unexpected error: \(error)")
        case .noVariantFound:
            print("No variant found")
        case .invalidURL:
            print("Invalid URL")
        case .noSegmentsFound:
            print("No segments found")
        }
    }

    enum PlayerError: Error {
        case networkError(URLError)
        case parserError(HLSParserError)
        case playerError(Error)
        case unexpectedError(Error)
        case noVariantFound
        case invalidURL
        case noSegmentsFound
    }

    private enum Config {
        static let targetBandwidth = 1_727_000
    }
}

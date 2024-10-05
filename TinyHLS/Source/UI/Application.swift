import SwiftUI

@main
struct TinyHLSApp: App {
    let network: HLSNetworkHandler
    let parser: HLSParser

    init() {
        network = HLSNetworkHandler()
        parser = HLSParser()
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
            guard let url = URL(string: Constants.streamPath) else { return }
            let masterPlaylistData = try await network.downloadM3U8File(url: url)
            let parsedMasterPlaylist = try parser.parseMasterPlaylist(data: masterPlaylistData)

            let selectedVariant = parsedMasterPlaylist.variants
                .filter { $0.resolution != nil }
                .first(where: { $0.bandwidth == Config.targetBandwidth })

            guard let selectedVariant = selectedVariant else {
                return
            }

            guard let variantURL = URL(string: Constants.domain + selectedVariant.uri) else { return }
            let playlistData = try await network.downloadM3U8File(url: variantURL)
            let parsedPlaylist = try parser.parseMediaPlaylist(data: playlistData)

            print(parsedPlaylist.segments)
        } catch let error as URLError {
            handleError(.networkError(error))
        } catch let error as HLSParserError {
            handleError(.parserError(error))
        } catch let error as PlayerError {
            handleError(.playerError(error))
        } catch {
            handleError(.unexpectedError(error))
        }
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
            print("No variant found \(error)")
        }
    }

    enum PlayerError: Error {
        case networkError(URLError)
        case parserError(HLSParserError)
        case playerError(Error)
        case unexpectedError(Error)
        case noVariantFound
    }

    private enum Config {
        static let targetBandwidth = 1_727_000
    }
}

import Foundation

class HLSNetworkHandler {
    private let session: URLSession

    init() {
        session = URLSession(configuration: .default)
    }

    func downloadM3U8File(url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    // Modified function to download multiple .ts files concurrently, up to 3 at a time.
    // Implementing a queue to download and maintain order for HLS playback.
    func downloadTSFiles(urls: [URL]) async throws -> [Data] {
        return try await withThrowingTaskGroup(of: (Int, Data).self) { group in
            var segmentDataMap: [Int: Data] = [:]

            for (index, url) in urls.enumerated() {
                group.addTask {
                    let data = try await self.downloadFile(at: url)
                    return (index, data)
                }
            }

            for try await(index, data) in group {
                segmentDataMap[index] = data
            }

            return urls.indices.compactMap { segmentDataMap[$0] }
        }
    }

    private func downloadFile(at url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

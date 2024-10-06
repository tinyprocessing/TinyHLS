import Foundation

class Utils {
    static func chunkArray<T>(_ array: [T], chunkSize: Int) -> [[T]] {
        guard chunkSize > 0 else { return [] }
        var chunks: [[T]] = []
        var currentIndex = 0

        while currentIndex < array.count {
            let endIndex = min(currentIndex + chunkSize, array.count)
            let chunk = Array(array[currentIndex..<endIndex])
            chunks.append(chunk)
            currentIndex += chunkSize
        }

        return chunks
    }
}

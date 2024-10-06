import Foundation

class HLSBufferManager {
    private var buffer: [Data] = []
    private let lock = NSLock()
    private let maxBufferSize: Int
    private var currentIndex = 0

    init(maxBufferSize: Int) {
        self.maxBufferSize = maxBufferSize
    }

    // Adds data to the buffer while ensuring the buffer does not exceed the maximum size
    func addSegment(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }

        if buffer.count >= maxBufferSize {
            buffer.removeFirst() // Remove the oldest segment if buffer is full
        }
        buffer.append(data)
    }

    func getCurrentSegment() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return buffer.first
    }

    // Fetches the next segment to be processed in the correct order
    func getNextSegment() -> Data? {
        lock.lock()
        defer { lock.unlock() }

        guard currentIndex < buffer.count else { return nil }
        let segment = buffer[currentIndex]
        currentIndex += 1
        return segment
    }

    // Resets the buffer to start over or in case of errors
    func resetBuffer() {
        lock.lock()
        defer { lock.unlock() }

        buffer.removeAll()
        currentIndex = 0
    }

    // Peek at the current buffer status
    func getBufferStatus() -> (count: Int, remaining: Int) {
        lock.lock()
        defer { lock.unlock() }

        return (buffer.count, max(0, buffer.count - currentIndex))
    }

    // Utility function to check if buffer is ready for playback
    func isBufferReady() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return buffer.count >= 3
    }
}

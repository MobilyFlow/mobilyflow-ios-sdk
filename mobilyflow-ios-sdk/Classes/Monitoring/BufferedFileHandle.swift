//
//  BufferedFileHandle.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 24/01/2025.
//

import Foundation

/**
 A class that manage a FileHandle with a buffer
 */
class BufferedFileHandle {
    private var fileHandle: FileHandle
    private let fileURL: URL
    private var buffer: Data
    private let bufferSize: Int
    private let queue = DispatchQueue(label: "BufferedFileHandle")
    
    init(_ fileURL: URL, bufferSize: Int = 8096) throws {
        self.fileURL = fileURL
        self.bufferSize = bufferSize
        self.buffer = Data(capacity: bufferSize)
        
        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        }
        
        // Open file for writing (append mode)
        self.fileHandle = try FileHandle(forWritingTo: fileURL)
        self.fileHandle.seekToEndOfFile()
    }
    
    func write(string: String) {
        self.write(data: string.data(using: .utf8)!)
    }
    
    func write(data: Data) {
        self.queue.async {
            var remainingBufferCapacity = self.bufferSize - self.buffer.count
            if data.count < remainingBufferCapacity {
                self.buffer.append(data)
            } else if data.count == remainingBufferCapacity {
                self.buffer.append(data)
                self._flush()
            } else {
                data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                    var unsafeBuffer = ptr.bindMemory(to: UInt8.self).baseAddress!
                    var remainingDataSize = data.count
                    
                    while remainingDataSize > 0 {
                        self.buffer.append(unsafeBuffer, count: min(remainingDataSize, remainingBufferCapacity))
                        
                        remainingDataSize -= remainingBufferCapacity
                        
                        if self.buffer.count >= self.bufferSize {
                            self._flush()
                        }
                        
                        if remainingDataSize > 0 {
                            unsafeBuffer = unsafeBuffer.advanced(by: remainingBufferCapacity)
                            remainingBufferCapacity = self.bufferSize
                        }
                    }
                }
            }
        }
    }
    
    private func _flush() {
        if !buffer.isEmpty {
            fileHandle.write(buffer)
            buffer.removeAll()
        }
    }
    
    func flush() {
        self.queue.sync {
            self._flush()
        }
    }
    
    func close() {
        self.queue.sync {
            _flush()
            try? fileHandle.close()
        }
    }
    
    deinit {
        close()
    }
}

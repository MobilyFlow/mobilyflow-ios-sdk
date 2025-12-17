//
//  Logger.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 23/01/2025.
//

import Foundation
import UIKit

enum LogFolderType: String {
    case RAW_LOGS = "raw"
    case EXPORT_LOGS = "export"
    case PROCESSING_LOGS = "processing"
}

class Logger {
    private static var allowLogging = false
    private static var tag = ""
    private static var slug = ""
    
    static var fileHandle: BufferedFileHandle?
    static var lastWritingDate = Date(timeIntervalSince1970: 0)
    
    static var queue = DispatchQueue(label: "MobilyFlow-Logger")
    private static var flushTask: Timer?
    
    private static var lifecycleManager: AppLifecycleManager?
    
    private static let dateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFractionalSeconds, .withInternetDateTime]
        return formatter
    }()
    
    static func initialize(tag: String, allowLogging: Bool) {
        self.allowLogging = allowLogging
        self.tag = tag
        self.slug = slugify(tag)
        
        ensureFileRotation()
        startFlushTask()
        
        // Register to lifecycle
        lifecycleManager = AppLifecycleManager()
        lifecycleManager!.registerDidEnterBackground {
            self.flush()
        }
        lifecycleManager!.registerWillTerminate {
            print("App Terminate")
            self.close()
        }
    }
    
    static func close() {
        if self.fileHandle == nil {
            return
        }
        
        lifecycleManager?.unregisterAll()
        stopFlushTask()
        queue.sync {
            self.fileHandle!.close()
        }
    }
    
    private static func startFlushTask() {
        stopFlushTask()
        
        flushTask = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            self.flush()
        }
    }
    
    private static func stopFlushTask() {
        self.flush()
        if flushTask != nil {
            flushTask!.invalidate()
            flushTask = nil
        }
    }
    
    static func getLogFolder(type: LogFolderType?) throws -> URL {
        let fileManager = FileManager.default
        
        var baseFolder = try fileManager.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        baseFolder = baseFolder.appendingPathComponent("mobilyflow").appendingPathComponent("logs")
        
        if let type = type {
            baseFolder = baseFolder.appendingPathComponent(type.rawValue)
        }
        
        if !fileManager.fileExists(atPath: baseFolder.path) {
            try fileManager.createDirectory(at: baseFolder, withIntermediateDirectories: true, attributes: nil)
        }
        
        return baseFolder
    }
    
    static func getLogFileName(date: Date? = nil) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
    
        return self.slug + "_" + formatter.string(from: date ?? Date()) + ".log"
    }
    
    private static func ensureFileRotation() {
        let nowDate = Date()
            
        do {
            if self.fileHandle == nil || nowDate.isAfterDay(self.lastWritingDate) {
                let logFolder = try getLogFolder(type: .RAW_LOGS)
                let logFile = logFolder.appendingPathComponent(getLogFileName())
            
                try self.queue.sync {
                    // 1. Close old stream
                    if self.fileHandle != nil {
                        self.fileHandle?.close()
                    }
                    
                    // 2. Create new stream
                    self.fileHandle = try BufferedFileHandle(logFile)
                    lastWritingDate = nowDate
                }
                
                // 3. Delete old file in a new thread
                DispatchQueue.global(qos: .background).async {
                    do {
                        let allLogFiles = try FileManager.default.contentsOfDirectory(atPath: logFolder.path).sorted()
                        let pattern = "^\(slug)_(.+)\\.log$"
                        let regex = try NSRegularExpression(pattern: pattern)
                        let dateParser = DateFormatter()
                        dateParser.dateFormat = "yyyy-MM-dd"

                        for logFile in allLogFiles {
                            if logFile.hasPrefix(slug + "_") && logFile.hasSuffix(".log") {
                                let range = NSRange(logFile.startIndex ..< logFile.endIndex, in: logFile)
                                if let match = regex.firstMatch(in: logFile, options: [], range: range) {
                                    // Ensure we have at least one capture group.
                                    if match.numberOfRanges > 1,
                                       let captureRange = Range(match.range(at: 1), in: logFile)
                                    {
                                        let dateString = String(logFile[captureRange])
                                        if let fileDate = dateParser.date(from: dateString) {
                                            let daysBetween = nowDate.dayUntil(fileDate)
                                            if daysBetween >= 5 {
                                                try? FileManager.default.removeItem(at: logFolder.appendingPathComponent(logFile))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } catch {
                        Logger.e("Removing old log file error", error: error)
                    }
                }
            }
        } catch {
            Logger.e("Failed to open file", error: error)
        }
    }
    
    private static func slugify(_ input: String) -> String {
        // Step 1: Normalize string to remove diacritics
        var slug = input.folding(options: .diacriticInsensitive, locale: .current)
            
        // Step 2: Replace special characters with empty string
        let allowedCharacterSet = CharacterSet.alphanumerics.union(CharacterSet.whitespaces).union(CharacterSet(arrayLiteral: "_"))
        let filteredString = slug.unicodeScalars.filter { allowedCharacterSet.contains($0) }
        slug = String(String.UnicodeScalarView(filteredString))
            
        // Step 3: Replace spaces with hyphens
        slug = slug.replacingOccurrences(of: " ", with: "-")
            
        // Step 4: Replace multiple hyphens with a single hyphen
        slug = slug.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            
        // Step 5: Remove trailing hyphens and convert to lowercase
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-")).lowercased()
            
        return slug
    }
    
    private static func flush() {
        if self.fileHandle == nil {
            return
        }
        
        queue.sync {
            self.fileHandle!.flush()
        }
    }
    
    static func log(_ level: LogLevel, _ message: String, error: Error? = nil) {
        ensureFileRotation()
        
        let time = dateFormatter.string(from: Date())
        
        if allowLogging || level == .error || level == .warn {
            print("\(time) [\(tag)] \(LogLevel.getIcon(level)) \(message)")
            
            if error != nil {
                print("\t\(error!): \(error!.localizedDescription)")
            }
        }
        
        var message = "\(time) [\(LogLevel.getLabel(level))] \(message)"
        if error != nil {
            message += "\n\t\(error!): \(error!.localizedDescription)"
        }
        CrashlyticsLogger.log(message)
        message += "\n"
        self.fileHandle?.write(string: message)
    }
    
    static func d(_ message: String, error: Error? = nil) {
        log(.debug, message, error: error)
    }

    static func w(_ message: String, error: Error? = nil) {
        log(.warn, message, error: error)
    }

    static func e(_ message: String, error: Error? = nil) {
        log(.error, message, error: error)
    }
}

//
//  Monitoring.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 27/01/2025.
//

import Foundation

public class Monitoring {
    private static var sendHandler: ((URL) async throws -> Void)?
    private static var sendTask: Timer?
    
    private init() {}
    
    public static func initialize(tag: String, allowLogging: Bool, sendHandler: @escaping ((URL) async throws -> Void)) {
        self.sendHandler = sendHandler
        Logger.initialize(tag: tag, allowLogging: allowLogging)
        
        // TODO: This should be removed and is here for retro-compatibility
        
        // Move old log to new structure
        do {
            let baseLogFolder = try Logger.getLogFolder(type: nil)
            let rawLogFolder = try Logger.getLogFolder(type: .RAW_LOGS)
            
            let listFiles = try FileManager.default.contentsOfDirectory(at: baseLogFolder, includingPropertiesForKeys: nil)
            for oldFile in listFiles {
                if FileManager.default.isReadableFile(atPath: oldFile.path) && oldFile.path.hasSuffix(".log") {
                    let newFile = rawLogFolder.appendingPathComponent(oldFile.lastPathComponent)
                    
                    if FileManager.default.fileExists(atPath: newFile.path) {
                        // New file already exists, remove the old one
                        Logger.d("Remove old log file \(oldFile.path)")
                        try FileManager.default.removeItem(at: oldFile)
                    } else {
                        Logger.d("Move old log file \(oldFile.path) to \(newFile.path)")
                        try FileManager.default.moveItem(at: oldFile, to: newFile)
                    }
                }
            }
        } catch {
            Logger.e("Can't move log to new structure", error: error)
        }
        
        // ----------------------------------------------------------------
        
        startSendTask()
    }
    
    private static func checkInit(throwOnError: Bool = true) throws -> Bool {
        if self.sendHandler == nil {
            if throwOnError {
                throw NSError(domain: "Monitoring not initialized", code: 0)
            }
            return false
        }
        return true
    }
    
    private static func startSendTask() {
        stopSendTask()
        
        let sendAction = { () async in
            do {
                let exportFolder = try Logger.getLogFolder(type: .EXPORT_LOGS)
                if FileManager.default.fileExists(atPath: exportFolder.path) {
                    let listFiles = try FileManager.default.contentsOfDirectory(at: exportFolder, includingPropertiesForKeys: nil)
                    for file in listFiles {
                        if FileManager.default.isReadableFile(atPath: file.path) && file.path.hasSuffix(".log") {
                            await self.sendLogFile(file)
                        }
                    }
                }
            } catch {
                Logger.e("Error in Monitoring sendTask", error: error)
            }
        }
        
        // Execute first after 2s, then, every 60s
        Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in
            Task(priority: .background) {
                await sendAction()
                DispatchQueue.main.async {
                    sendTask = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                        Task(priority: .background, operation: sendAction)
                    }
                }
            }
        }
    }
    
    private static func stopSendTask() {
        sendTask?.invalidate()
        sendTask = nil
    }
    
    private static func close() {
        guard let _ = try? checkInit() else {
            return
        }
        
        Logger.close()
    }
    
    /*
     Export logs from fromDate to toDate (both included) into a new file.
     
     startDate and toDate both default to now() if they are null.
     If clearLogs is true, remove exported logfiles.
     */
    private static func exportLogs(fromDate: Date? = nil, toDate: Date? = nil, clearLogs: Bool = false) throws -> URL {
        var from = fromDate ?? Date()
        let to = toDate ?? Date()
        
        let rawLogFolder = try Logger.getLogFolder(type: .RAW_LOGS)
        let processingLogFolder = try Logger.getLogFolder(type: .PROCESSING_LOGS)
        let exportLogFolder = try Logger.getLogFolder(type: .EXPORT_LOGS)
        
        let processingFile = processingLogFolder.appendingPathComponent(String(Int(Date().timeIntervalSince1970 * 1000)) + ".log")
        let exportFile = exportLogFolder.appendingPathComponent(String(Int(Date().timeIntervalSince1970 * 1000)) + ".log")
        
        if !FileManager.default.fileExists(atPath: processingFile.path) {
            FileManager.default.createFile(atPath: processingFile.path, contents: nil, attributes: nil)
        }
        let writer = try FileHandle(forWritingTo: processingFile)
        
        while !from.isAfterDay(to) { // Is before or equal
            let logFile = rawLogFolder.appendingPathComponent(Logger.getLogFileName(date: from))
            
            if FileManager.default.fileExists(atPath: logFile.path) && FileManager.default.isReadableFile(atPath: logFile.path) {
                if Logger.lastWritingDate.isSameDay(from) {
                    // In case we export the current logFile, we need to synchronize the read process
                    Logger.queue.sync {
                        if clearLogs {
                            Logger.fileHandle?.close()
                        } else {
                            Logger.fileHandle?.flush()
                        }
                        
                        do {
                            let reader = try FileHandle(forReadingFrom: logFile)
                            while let buffer = try reader.read(upToCount: 8096), !buffer.isEmpty {
                                writer.write(buffer)
                            }
                            try reader.close()
                            
                            if clearLogs {
                                try FileManager.default.removeItem(at: logFile)
                                Logger.fileHandle = try BufferedFileHandle(logFile)
                            }
                        } catch {
                            Logger.e("Error exporting log file \(logFile) (sync)", error: error)
                        }
                    }
                } else {
                    do {
                        let reader = try FileHandle(forReadingFrom: logFile)
                        while let buffer = try reader.read(upToCount: 8096), !buffer.isEmpty {
                            writer.write(buffer)
                        }
                        try reader.close()
                    
                        if clearLogs {
                            try FileManager.default.removeItem(at: logFile)
                        }
                    } catch {
                        Logger.e("Error exporting log file \(logFile)", error: error)
                    }
                }
            }
            from = from.addingTimeInterval(24 * 3600)
        }
        
        try writer.close()
        
        // Move file from processing to export folder
        try FileManager.default.moveItem(at: processingFile, to: exportFile)
        
        return exportFile
    }
    
    /*
     Export logs from sinceDays to now().
     
     If sinceDays is 0, export only today, if it 1 export also yesterday, etc...
     If clearLogs is true, remove exported logfiles
     */
    private static func exportLogs(sinceDays: Int = 0, clearLogs: Bool = false) throws -> URL {
        return try self.exportLogs(fromDate: Date().addingTimeInterval(TimeInterval(-sinceDays * 24 * 3600)), toDate: nil, clearLogs: clearLogs)
    }
    
    private static func sendLogFile(_ logFile: URL) async {
        if !(try! checkInit(throwOnError: false)) {
            return
        }

        do {
            try await self.sendHandler!(logFile)
            try FileManager.default.removeItem(at: logFile) // No exception in sendHandler -> Remove file
        } catch {
            // Exception in sendHandler or exportLogs, retry sending logs next time
            Logger.e("[exportDiagnostics] Error", error: error)
        }
    }
    
    static func exportDiagnostic(sinceDays: Int) throws {
        _ = try checkInit()

        Task(priority: .background) {
            do {
                let exportFile = try self.exportLogs(sinceDays: sinceDays, clearLogs: true)
                await sendLogFile(exportFile)
            } catch {
                // Exception in sendHandler or exportLogs, retry sending logs next time
                Logger.e("[exportDiagnostics] Error", error: error)
            }
        }
    }
}

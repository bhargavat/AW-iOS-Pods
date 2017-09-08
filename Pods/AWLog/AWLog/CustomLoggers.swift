//
//  AWTTYLogger.swift
//  AWLog
//
//  Copyright © 2016 VMware, Inc. All rights reserved.
//  This product is protected by copyright and intellectual property laws in the United States and
//  other countries as well as by international treaties.
//  AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import CocoaLumberjack

private let terminalLoggingQueue = DispatchQueue(label: "com.air-watch.logger.terminal", attributes: [])
private let fileLoggingQueue = DispatchQueue(label: "com.air-watch.logger.file", attributes: [])
private let aslLoggingQueue = DispatchQueue(label: "com.air-watch.logger.asl", attributes: [])


internal class TTYLogger: DDTTYLogger {
    
    override init() {
        super.init()
        self.logFormatter = LogFormatter()
        self.loggerQueue = terminalLoggingQueue;
    }
    
    override var loggerName: String {
        return "vmware.airwatch.TTYLogger"
    }    
}

internal class ASLLogger: DDASLLogger {
    override init() {
        super.init()
        self.logFormatter = LogFormatter(formatter: ASLLogFormatter())
        self.loggerQueue = aslLoggingQueue
    }
    
    override var loggerName: String! {
        return "vmware.airwatch.ASLLogger"
    }
}

fileprivate class AWCommandLogFileManager: DDLogFileManagerDefault {
    fileprivate let logFileName = "com.vmware.air-watch.command.log"
    fileprivate override var newLogFileName: String! {
        get {
            return logFileName
        }
    }

    fileprivate override func isLogFile(withName fileName: String!) -> Bool {
        return fileName == logFileName
    }
}


internal class FileLogger: DDFileLogger {
    fileprivate static let MaximumNumberOfLogfiles = UInt(1)         // Logs will be written to only 1 file before being purged.
    fileprivate static let MaximumLogFileSize      = UInt64(5242880)   // 5 * 1024 * 1024 Bytes (5MB)
    fileprivate static let LogRollingFrequency     = TimeInterval(172800)    // 48 * 60 * 60 (48 Hours)
    
    static let sharedFileLogger = FileLogger.airwatchFileLogger()
    static let commandFileLogger = FileLogger.awCommandFileLogger()
    
    override init!(logFileManager: DDLogFileManager!) {
        super.init(logFileManager: logFileManager)
        self.logFormatter = LogFormatter()
        self.loggerQueue = fileLoggingQueue
    }

    fileprivate static func awCommandFileLogger() -> FileLogger {
        // Initialize File Logger
        let path = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first
        let fileManager = AWCommandLogFileManager(logsDirectory: path)
        fileManager?.maximumNumberOfLogFiles = 1
        guard let logger = FileLogger(logFileManager: fileManager) else {
            fatalError("Failed to generate file logger with path: \(path ?? "cannot generate file logger")")
        }
        return logger
    }
    
    fileprivate static func airwatchFileLogger() -> FileLogger {
        // Initialize File Logger
        let path = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first
        let fileManager = DDLogFileManagerDefault(logsDirectory: path)
        fileManager?.maximumNumberOfLogFiles = FileLogger.MaximumNumberOfLogfiles
        guard let logger = FileLogger(logFileManager: fileManager) else {
            fatalError("Failed to generate file logger with path: \(path ?? "cannot generate file logger")")
        }
        logger.maximumFileSize = FileLogger.MaximumLogFileSize
        logger.rollingFrequency = FileLogger.LogRollingFrequency
        return logger
    }
    
    override var loggerName: String! {
        return "vmware.airwatch.FileLogger"
    }
    
    internal func purgeLogFile(_ completion: @escaping (() -> Void) = {}) {
        self.rollLogFile {
            self.logFileManager.unsortedLogFileInfos.filter { $0.isArchived }.forEach {
                $0.reset()
                try? FileManager.default.removeItem(atPath: $0.filePath)
            }
            completion()
        }
    }
    
    internal func isArchived(_ logfilePath: String) -> Bool {
        let logfile = DDLogFileInfo(filePath: logfilePath)
        return logfile?.isArchived ?? false;
    }
    
    internal func getLogData() -> Data?{
        return try? Data(contentsOf: URL(fileURLWithPath: self.currentLogFileInfo.filePath))
    }
    
    internal override func willRemove() {
        /*  
         * This function is left empty on purpose to override its super class's implementation, which is to prevent the CocoaLumberjack from removing the current log file when the file logger is removed from logger collection.
         */
        return
    }
}

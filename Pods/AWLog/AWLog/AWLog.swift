//
//  AWLog.swift
//  AWLog
//
//  Copyright © 2016 VMware, Inc. All rights reserved.
//  This product is protected by copyright and intellectual property laws in the United States and 
//  other countries as well as by international treaties.
//  AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import CocoaLumberjack


public typealias AWLogFlag = DDLogFlag
public typealias AWLogLevel = DDLogLevel

public enum AWLogType: Int {
    case none = 0              // Output no type.
    case application = 1       // Output application logs.
    case crash = 2             // Output crash logs.
    case device = 3            // Output device logs.
}

@objc
open class AWLogger: NSObject {
    
    internal let commonLogger = LoggersCollection(types: [.tty, .file, .asl], logLevel: globalLogLevel)
    internal let secureLogger = LoggersCollection(types: [.file], logLevel: DDLogLevel.all)
    internal let privateLogger = LoggersCollection(types: [.tty, .file], logLevel: DDLogLevel.all)
    
    fileprivate var tag = Bundle.main.bundleIdentifier ?? "com.air-watch.vmware.logger"
    internal var context:Int = 0
    
    internal static var nextLoggerContext:Int = 108 //a semi perfect number to start with.
    fileprivate static var currentLoggers: [String: AWLogger] = [:]
    
    /**
     Global default logger without any application Context. Logs using this logger will be written to
     Log statements will be filtered based on global log level.
     
     This logger is provided as a bridge between current logger implementation to newer version.
     
     AWLogger.defaultLogger.logError("Some Error Statements.")
     (or)
     let logger = AWLogger.defaultLogger
     logger.logError("Error message")
     ...
     logger.logDebug("Debug Message")
     */
    open static let sharedInstance = AWLogger.getlogger(Bundle.main.bundleIdentifier ?? "")
    fileprivate static var _globalLogLevel: AWLogLevel = .verbose;
    open static var globalLogLevel: AWLogLevel {
        get {
            return _globalLogLevel
        }
        set {
            _globalLogLevel = newValue
            AWLogger.currentLoggers.forEach { (module, logger) in
                logger.commonLogger.setLogLevel(_globalLogLevel)
//                logger.privateLogger.setLogLevel(_globalLogLevel)
//                logger.secureLogger.setLogLevel(_globalLogLevel)
            }
        }
    }
    
    open static func purgeLogs() {
        FileLogger.sharedFileLogger.purgeLogFile()
    }
    
    open static func getlogger(_ module: String) -> AWLogger {
        if let logger = currentLoggers[module] {
            return logger
        }

        let logger = AWLogger()
        logger.tag = module
        logger.context = module.hashValue
        currentLoggers[module] = logger
        return logger
    }
    
    open static func getLogsFilesData() -> Data? {
        return FileLogger.sharedFileLogger.getLogData()
    }

    open static func activateCommandLogger(level: AWLogLevel) -> () {
        self.sharedInstance.commonLogger.add(FileLogger.commandFileLogger, with: level)
    }

    open static func deactivateCommandLogger() -> () {
        FileLogger.commandFileLogger.purgeLogFile {
            self.sharedInstance.commonLogger.remove(FileLogger.commandFileLogger)
        }
    }

    open static func getCommandLogFilesData() -> Data? {
        return FileLogger.commandFileLogger.getLogData()
    }

    fileprivate static var whitelistedContexts = Set<Int>()
    fileprivate static var blacklistedContexts = Set<Int>()
    
    fileprivate static func updateFormatters() {
        let blacklistedContextsArray = Array(blacklistedContexts);
        let whitelistedContextsArray = Array(whitelistedContexts);
        
        if let ttyFormatter = TTYLogger.sharedInstance().logFormatter as? LogFormatter {
            ttyFormatter.whitelist(whitelistedContextsArray)
            ttyFormatter.blacklist(blacklistedContextsArray)
        }

        if let aslFormatter = ASLLogger.sharedInstance().logFormatter as? LogFormatter {
            aslFormatter.whitelist(whitelistedContextsArray)
            aslFormatter.blacklist(blacklistedContextsArray)
        }

        if let fileFormatter = FileLogger.sharedFileLogger.logFormatter as? LogFormatter {
            fileFormatter.whitelist(whitelistedContextsArray)
            fileFormatter.blacklist(blacklistedContextsArray)
        }
        
    }
    
    open static func whitelist(_ modules: [String]) {
        modules
            .map{ $0.hashValue }
            .forEach { (context) in
                whitelistedContexts.insert(context)
                blacklistedContexts.remove(context)
            }
        AWLogger.updateFormatters()
    }

    open static func blacklist(_ modules: [String]) {
        modules
            .map{ $0.hashValue }
            .forEach { (context) in
                blacklistedContexts.insert(context)
                whitelistedContexts.remove(context)
        }
        
        AWLogger.updateFormatters()
    }
}

extension AWLogger {
    
    @objc(logError:function:file:line:)
    public func log(error input: String, function: String = #function, file: String = #file, line: UInt = #line) {
        let logMessage = DDLogMessage(message: input,
                                      level: AWLogger.globalLogLevel,
                                      flag: DDLogFlag.error,
                                      context: self.context,
                                      file: file,
                                      function: function,
                                      line: line,
                                      tag: self.tag,
                                      options: DDLogMessageOptions(rawValue: 0),
                                      timestamp: Date())
        self.commonLogger.log(asynchronous: false, message: logMessage)
    }
    
    @objc(logWarning:function:file:line:)
    public func log(warning input: String, function: String = #function, file: String = #file, line: UInt = #line) {
        let logMessage = DDLogMessage(message: input,
                                      level: AWLogger.globalLogLevel,
                                      flag: DDLogFlag.warning,
                                      context: self.context,
                                      file: file,
                                      function: function,
                                      line: line,
                                      tag: self.tag,
                                      options: DDLogMessageOptions(rawValue: 0),
                                      timestamp: Date())
        self.commonLogger.log(asynchronous: false, message: logMessage)
    }
    
    @objc(logInfo:function:file:line:)
    public func log(info input: String, function: String = #function, file: String = #file, line: UInt = #line) {
        let logMessage = DDLogMessage(message: input,
                                      level: AWLogger.globalLogLevel,
                                      flag: DDLogFlag.info,
                                      context: self.context,
                                      file: file,
                                      function: function,
                                      line: line,
                                      tag: self.tag,
                                      options: DDLogMessageOptions(rawValue: 0),
                                      timestamp: Date())
        self.commonLogger.log(asynchronous: true, message: logMessage)
    }
    
    @objc(logVerbose:function:file:line:)
    public func log(verbose input: String, function: String = #function, file: String = #file, line: UInt = #line) {
        let logMessage = DDLogMessage(message: input,
                                      level: AWLogger.globalLogLevel,
                                      flag: DDLogFlag.verbose,
                                      context: self.context,
                                      file: file,
                                      function: function,
                                      line: line,
                                      tag: self.tag,
                                      options: DDLogMessageOptions(rawValue: 0),
                                      timestamp: Date())
        self.commonLogger.log(asynchronous: true, message: logMessage)
    }
    
    @objc(logDebug:function:file:line:)
    public func log(debug input: String, function: String = #function, file: String = #file, line: UInt = #line) {
        #if DEBUG
        let logMessage = DDLogMessage(message: input,
                                      level: AWLogger.globalLogLevel,
                                      flag: DDLogFlag.debug,
                                      context: self.context,
                                      file: file,
                                      function: function,
                                      line: line,
                                      tag: self.tag,
                                      options: DDLogMessageOptions(rawValue: 0),
                                      timestamp: Date())
        self.privateLogger.log(asynchronous: true, message: logMessage)
        #endif
    }
    
    @objc(logSecure:function:file:line:)
    public func log(secure input: String, function: String = #function, file: String = #file, line: UInt = #line) {
        let logMessage = DDLogMessage(message: input,
                                      level: DDLogLevel.all,
                                      flag: DDLogFlag.info,
                                      context: self.context,
                                      file: file,
                                      function: function,
                                      line: line,
                                      tag: self.tag,
                                      options: DDLogMessageOptions(rawValue: 0),
                                      timestamp: Date())
        self.secureLogger.log(asynchronous: true, message: logMessage)
    }
}



public func AWLogError(_ input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    AWLogger.sharedInstance.log(error: input, function: function, file: file, line: line)
}

public func AWLogWarning(_ input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    AWLogger.sharedInstance.log(warning: input, function: function, file: file, line: line)
}

public func AWLogInfo(_ input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    AWLogger.sharedInstance.log(info: input, function: function, file: file, line: line)
}

public func AWLogVerbose(_ input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    AWLogger.sharedInstance.log(verbose: input, function: function, file: file, line: line)
}

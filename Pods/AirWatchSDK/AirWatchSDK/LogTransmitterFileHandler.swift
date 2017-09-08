//
//  LogTransmitterFileHandler.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

class LogTransmitterFileHandler {
    fileprivate static let fileQueue = DispatchQueue(label: "com.vmware.LogTransmitter.LogReportFileWriter", attributes: [])

    fileprivate var filepath: String = ""

    init(filename: String) {
        precondition(filename.characters.count > 0)
        self.filepath = fullpath(filename)
        ensureFileExist()
    }

    fileprivate func fullpath(_ filename: String) -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, [.userDomainMask], true)
        precondition(paths.count > 0)
        return paths[0] + "/\(filename)"
    }

    fileprivate func ensureFileExist() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: self.filepath) {
            precondition(fileManager.createFile(atPath: self.filepath, contents: nil, attributes: nil),
                         "Can't create log report file \(self.filepath)")
        }
    }

    func write(_ logData: Data) {
        LogTransmitterFileHandler.fileQueue.async {
            self.ensureFileExist()

            guard let file = FileHandle(forWritingAtPath: self.filepath) else {
                log(warning: "Can not write to file \(self.filepath)")
                return
            }

            file.seekToEndOfFile()
            file.write(logData)
            file.synchronizeFile()
            file.closeFile()
        }
    }

    func readToData() -> Data? {
        var data = Data()

        LogTransmitterFileHandler.fileQueue.sync {
            self.ensureFileExist()
            let file = FileHandle(forReadingAtPath: self.filepath)
            if let ret = file?.readDataToEndOfFile() {
                data.append(ret)
            }
            file?.closeFile()
        }

        guard data.count > 0 else {
            self.purge()
            return nil
        }

        return data
    }

    func purge() {
        LogTransmitterFileHandler.fileQueue.async {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: self.filepath) {
                do {
                    try fileManager.removeItem(atPath: self.filepath)
                } catch let err as NSError {
                    log(warning: "Error on deleting file \(self.filepath): \(err)")
                }
            }
        }
    }
}

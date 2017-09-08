//
//  DataSampleFileHandle.swift
//  AWDataSampler
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWHelpers
import AWError
import Foundation


let SampleLimit: Int = 200
let RoomToGrow: Int = 50


class DataSampleFileHandle {
    private let fileQueue = DispatchQueue(label: "com.vmware.datasampler.samples_file_writer")
    private var filepath: String = ""

    init(filename: String) {
        precondition(filename.characters.count > 0)        
        self.filepath = fullpath(filename)
        ensureFileExist()
    }
    
    init(file: DataSamplerFile) {
        self.filepath = fullpath(file.rawValue)
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
                         "Can't create data sample file \(self.filepath)")
        }
    }
    
    func write(samples: [DataSample]) {
        self.fileQueue.async {
            self.ensureFileExist()
            guard let file = FileHandle(forWritingAtPath: self.filepath) else {
                log(warning: "Can not write to file \(self.filepath)")
                return
            }
            file.seekToEndOfFile()
            samples.forEach{ (sample) in
                var data: Data
                do {
                    data = try sample.data()
                } catch let err {
                    log(error: "Error on writing samples (sample type \(sample.sampleType)): \(err)")
                    return
                }
                file.write(data)
            }
            
            file.synchronizeFile()
            file.closeFile()
            
            guard let readFile = FileHandle(forReadingAtPath: self.filepath) else {
                log(warning: "Error on reading sample file \(self.filepath)")
                return
            }
            
            defer {
                readFile.closeFile()
            }
            
            let data = readFile.availableData
            let samplesCount = self.sampleCount(sampleData: data)
            if (samplesCount == -1) {
                log(warning: "Error on getting samples count! -- Clearing \(self.filepath)")
                self.purge()
            } else if (samplesCount > SampleLimit) {
                // Remove old samples
                var trimmed = data
                for _ in 1...(samplesCount - SampleLimit + RoomToGrow) {
                    trimmed = self.removeFirst(sampleData: trimmed)
                }
                precondition(self.sampleCount(sampleData: trimmed) == (SampleLimit - RoomToGrow),
                             "Failed to trim the samples properly!")
                
                /// replace data
                guard let writeFile = FileHandle(forUpdatingAtPath: self.filepath) else {
                    log(warning: "Error on updating sample file \(self.filepath)")
                    return
                }
                writeFile.truncateFile(atOffset: 0)
                writeFile.write(trimmed)
                writeFile.synchronizeFile()
                writeFile.closeFile()
            }
        }
    }
    
    func readToData() -> Data {
        var data = Data()
        
        fileQueue.sync {
            self.ensureFileExist()
            let file = FileHandle(forReadingAtPath: self.filepath)
            if let ret = file?.readDataToEndOfFile() {
                data.append(ret)
            }
            file?.closeFile()
        }
        
        return data
    }
    
    func purge() {
        self.fileQueue.async {
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
    
    private func sampleCount(sampleData: Data) -> Int {
        var length = sampleData.count
        var count: Int = 0
        var next: Int = 0
        
        while (length > 0) {
            if (sampleData.count >= (next + MemoryLayout<UInt16>.size + MemoryLayout<UInt16>.size)) {
                var messageSize: UInt16 = 0
                (sampleData as NSData).getBytes(&messageSize, range: NSMakeRange(next + MemoryLayout<UInt16>.size, MemoryLayout<UInt16>.size))
                /// 18 is the size of base sample
                if (messageSize > UInt16.max || messageSize < 18) {
                    count = -1
                    break
                }
                next = next + Int(messageSize)
                length = length - Int(messageSize)
                count = count + 1
            } else {
                // Data might be corrupted
                count = -1
                break
            }
        }
        return count
    }
    
    private func removeFirst(sampleData: Data) -> Data {
        
        var messageSize: UInt16 = 0
/// Original: 
///     (sampleData as NSData).getBytes(&messageSize, range: NSMakeRange(MemoryLayout<UInt16>.size, MemoryLayout<UInt16>.size))

/// Swift 3:
        /// UInt 16 size will always be 2 bytes
        /// We skip first 2 bytes and read next two bytes, as message size.
        withUnsafeMutablePointer(to: &messageSize) { (buffer) in
            _ = sampleData.copyBytes(to: UnsafeMutableBufferPointer(start: buffer, count: 1), from: 2..<4)
        }
        log(verbose: "Remove sample (size: \(messageSize) bytes")

///      original:
///      return sampleData.subdata(in: NSMakeRange(Int(messageSize), sampleData.count - Int(messageSize)))
        return sampleData.subdata(in: Int(messageSize)..<sampleData.count)
    }
}

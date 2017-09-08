//
//  AWCipheredData.swift
//  AWCryptoKit
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWError
import AWLog
import Security

extension AWError.SDK.CryptoKit {
    enum FileCryptor: AWSDKErrorType {
        case streamNotOpened
        case failedToGenerateHeader
        case updateReadDataFailed
        case noDataMovedOut
        case sourceFileCannotBeHandled
        case invalidHeaderSignatureSize
        case failedToGetHeaderInfo
        case headerSignatureNotMatch
        case smallerThanMinimumSize
        case failedToGetAllTheNecessaryInfoForHeader
        case invalidFileSize
        case fileSizeNotMatch
        case invalidHeaderSize
        case failToGetIVData
    }
}

struct FileCipherMessage: CipherMessage {
    // The default version size is 6(valid bytes) + 2(zero bytes) = 8 bytes
    fileprivate static let versionSize = 8
    fileprivate static let minmumIVSize = 0
    fileprivate static let maximumIVSize = Int(kCCKeySizeAES256)
    fileprivate static let minmumHeaderSize = versionSize + minmumIVSize
    fileprivate static let maximumHeaderSize = versionSize + maximumIVSize
    var algorithm: CipherAlgorithm
    var blockMode: BlockCipherMode
    var ivSize: Int
}

public struct FileCryptor {
    public enum Operation {
        case encrypt
        case decrypt
    }
    
    let sourceFilepath: String
    let destinationFilepath: String
    let key: Data
    
    var inputStream: InputStream
    var outputStream: OutputStream
    
    var fileCipherMessage = FileCipherMessage.defaultMessage
    
    var bufferedCryptor: BufferedSharedKeyCryptor!
    
    let bufferSize: size_t = 1024
    var operation = FileCryptor.Operation.encrypt
    
// MARK: Initialization Part
    public init?(source: String, destination: String, key: Data) {
        guard key.count > 0 else {
            log(error:"Need  key to encrypt/decrypt.")
            return nil
        }
        
        guard FileManager.default.fileExists(atPath: source) else {
            log(error:"Provided Input File does not exist!")
            return nil
        }
        
        let destinationFilePathURL = URL(fileURLWithPath: destination)
        // if destination file exists, delete first
        if FileManager.default.fileExists(atPath: destination) {
            do {
                try FileManager.default.removeItem(at: destinationFilePathURL)
            } catch {
                log(error:"Failed to delete the destination file which is already existed")
                return nil
            }
        }
        // after deletion, creat a new empty file at the destination path
        FileManager.default.createFile(atPath: destination, contents: nil, attributes: nil)
        
        self.sourceFilepath = source
        self.destinationFilepath  = destination
        self.key = key
        
        // set up input stream
        guard FileCryptor.setFileProtectionAttributes(atPath: self.sourceFilepath),
            let sourceFileInputStream = InputStream(fileAtPath: self.sourceFilepath) else {
            log(error:"Cannot build input stream from the source file")
            return nil
        }
        self.inputStream = sourceFileInputStream
        
        // set up output stream
        guard FileCryptor.setFileProtectionAttributes(atPath: self.destinationFilepath),
            let destinationFileOutputStream = OutputStream(url: destinationFilePathURL, append: false) else {
            log(error:"Cannot build output stream from the destination file")
            return nil
        }
        
        self.outputStream = destinationFileOutputStream
    }
    
    
// MARK: Start opertion part
    mutating func start(with completion: @escaping (_ success: Bool, _ error: Error?) -> Void) -> () {
        switch self.operation {
        case .encrypt:
            self.encrypt(with: completion)
        case .decrypt:
            self.decrypt(with: completion)
        }
    }
    
// MARK: Read and Write Part
    fileprivate func performReadAndWrite(with completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        let copySelf = self
        DispatchQueue.global(qos: .default).async {
            // read 1024 bytes from source file and then encrypt using the buffered cryptor
            // or
            // read 1024 bytes from source file and then decrypt using the buffered cryptor
            var inputData = Data(count: copySelf.bufferSize)
            while copySelf.inputStream.hasBytesAvailable {
                let numberOfBytesToRead = inputData.withUnsafeMutableBytes{ (bytes) -> Int in
                    return copySelf.inputStream.read(bytes, maxLength: copySelf.bufferSize)
                }
                
                if numberOfBytesToRead > 0 {
                    let readData = inputData.withUnsafeBytes{ (bytes) -> Data in
                        return Data(bytes: bytes, count: numberOfBytesToRead)
                    }
                    let updatedData = try? copySelf.bufferedCryptor.update(readData)
                    
                    guard let outputData = updatedData, let dataOutMoved = updatedData?.count, dataOutMoved > 0 else {
                        log(error:"No data has been moved out")
                        completion(false, AWError.SDK.CryptoKit.FileCryptor.noDataMovedOut)
                        return
                    }
                    // Write the encrypted data to the destination file
                    // or 
                    // Write the decrypted data to the destination file.
                    let numberOfBytesWritten = outputData.withUnsafeBytes{ (bytes) -> Int in
                        copySelf.outputStream.write(bytes, maxLength: dataOutMoved)
                    }
                    if numberOfBytesWritten < 0 {
                        log(error:"Write error: \(String(describing: copySelf.outputStream.streamError))");
                        completion(false, copySelf.outputStream.streamError)
                        return
                    }
                }
            }
            
            // Encrypt the remaining data and write it to the destination file
            // or
            // Decrypt the remaining data and write it to the destination file
            let finalData = try? copySelf.bufferedCryptor.finalize()
            if let remainingData = finalData, let finalDataOutMoved = finalData?.count, finalDataOutMoved > 0 {
                let finalBytesWritten = remainingData.withUnsafeBytes{ (bytes) -> Int in
                    copySelf.outputStream.write(bytes, maxLength: finalDataOutMoved)
                }
                if finalBytesWritten < 0 {
                    log(error:"Write error: \(String(describing: copySelf.outputStream.streamError))");
                    completion(false, copySelf.outputStream.streamError)
                    return
                }
            }
            // Close file & call completion with success being true.
            copySelf.closeStreams()
            completion(true, nil)
        }
    }

    
// MARK: Encryption Part
    func generateHeader(with ivData: Data) throws -> Data {
        guard let versionData = self.fileCipherMessage.cryptoFormatString()?.data(using: String.Encoding.utf8) else {
            log(error:"Failed to generate the header data with AES256-CBC mode")
            throw AWError.SDK.CryptoKit.FileCryptor.failedToGenerateHeader
        }
        // version is 6 bytes, we need to make it 8 bytes, so we add 2 zero bytes
        let extraTwoZeroBytes = Data(count: 2)
        var headerData = Data()
        headerData.append(versionData)
        headerData.append(extraTwoZeroBytes)
        headerData.append(ivData)
        return headerData
    }
    
    func write(header headerData: Data) -> () {
        DispatchQueue.global(qos: .default).async {
            _ = headerData.withUnsafeBytes { (bytes) -> Int in
                self.outputStream.write(bytes, maxLength: headerData.count)
            }
        }
    }
    
    public mutating func encrypt(with completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        self.operation = .encrypt
        let ivData = Data.randomData(count: fileCipherMessage.ivSize)
        // Create a buffered cryptor with AES256-CBC mode
        self.setCryptor(with: ivData)
        // Generate header for the encryptor
        guard let header = try? self.generateHeader(with: ivData) else {
            log(error:"Failed to generate the header data with AES256-CBC mode")
            completion(false, AWError.SDK.CryptoKit.FileCryptor.failedToGenerateHeader)
            return
        }
        // Write header data to destination file first
        self.outputStream.open()
        self.write(header: header)
        self.inputStream.open()
        performReadAndWrite(with: completion)
    }
    
    
    
    
    
// MARK: Decryption Part
    mutating func setDecryptorFromFileSEG() -> Bool {
        // Read first Header bytes,
        guard let sourceFileHandler = FileHandle(forReadingAtPath: self.sourceFilepath) else {
            log(error:"Failed to get the file handler of the encrypted source file: \(AWError.SDK.CryptoKit.FileCryptor.sourceFileCannotBeHandled)")
            return false
        }
        
        let inputData = sourceFileHandler.readData(ofLength: 18)
        guard inputData.count >= 18 else {
            log(error:"The encypted source file does not has a valid Header Signature length: \(AWError.SDK.CryptoKit.FileCryptor.invalidHeaderSignatureSize)")
            return false
        }
        
        // get the header info which contains Header Signature and Header size
        guard let encryptedFileHeaderInfo = EncryptedFileHeaderInfo(fromData: inputData) else {
            log(error:"The Header Signature of encypted source file does not match: \(AWError.SDK.CryptoKit.FileCryptor.failedToGetHeaderInfo)")
            return false
        }
        
        let headerData = sourceFileHandler.readData(ofLength: Int(encryptedFileHeaderInfo.headerSize) - 18)
        sourceFileHandler.closeFile()

        guard headerData.count >= EncryptedFileHeader.minimumHeaderSize else {
            log(error:"The header size does not reach the minimum size: \(AWError.SDK.CryptoKit.FileCryptor.smallerThanMinimumSize)")
            return false
        }
        
        // get the remaining header data except for Header Signature and Header size
        guard let encryptedFileHeader = EncryptedFileHeader(fromData: headerData) else {
            log(error:"The header can not provide all the necessary info: \(AWError.SDK.CryptoKit.FileCryptor.failedToGetAllTheNecessaryInfoForHeader)")
            return false
        }
        
        // make sure the file size is valid
        guard encryptedFileHeader.fileSize > 0 else {
            log(error:"The file size must be greater than 0: \(AWError.SDK.CryptoKit.FileCryptor.invalidFileSize)")
            return false
        }

        self.inputStream.open()
        // Skip the header part and handle the encrypted part to the cryptor
        var encryptedFileHeaderData = Data(count: Int(encryptedFileHeaderInfo.headerSize))
        _ = encryptedFileHeaderData.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Int in
            self.inputStream.read(bytes, maxLength: Int(encryptedFileHeaderInfo.headerSize))
        }
        
        // use AWV0003
        self.fileCipherMessage = FileCipherMessage.AES128CBCWithIV
        self.setCryptor(with: encryptedFileHeader.ivData)
        return true
    }
    
    mutating func setDecryptorFromFile(with completion: (_ success: Bool, _ error: Error?) -> Void) -> Void {
        // If it is a SEG file, go to the SEG work flow
        if setDecryptorFromFileSEG() {
            return
        } else {
            // reset the offset
            self.inputStream.close()
            self.inputStream.open()
        }
        
        var needToReset = false
        
        var headerData = Data(count: FileCipherMessage.maximumHeaderSize)
        let dataRead = headerData.withUnsafeMutableBytes { (bytes) -> Int in
            // Read first Header bytes, which is the version info
            return self.inputStream.read(bytes, maxLength: FileCipherMessage.maximumHeaderSize)
        }
        guard dataRead == headerData.count && dataRead >= FileCipherMessage.minmumHeaderSize else {
            log(error:"The header size does not reach the minmum amount ")
            completion(false, AWError.SDK.CryptoKit.FileCryptor.invalidHeaderSize)
            return
        }
        
        let (message, iv, _) = FileCipherMessage.parse(headerData)
        
        if message == FileCipherMessage.AES256ECBNoIV {
            // While decrypting, If header version is v0 then there was no header information stored in file. So we would need to move file offset to start of file(reset = YES). The version used will be v2 and not v0 since file encryption uses AES-256 with CBC
            self.fileCipherMessage = FileCipherMessage.AES256CBCNoIV
            needToReset = true
        } else {
            self.fileCipherMessage = message
        }
        
        guard let ivData = iv else {
            log(error:"Fail to get the IV data")
            completion(false, AWError.SDK.CryptoKit.FileCryptor.failToGetIVData)
            return
        }
        // set up the cryptor
        self.setCryptor(with: ivData)
        // reset the input stream if needed
        if needToReset {
            self.inputStream.close()
            self.inputStream.open()
        }
    }
    
    public mutating func decrypt(with completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        self.operation = .decrypt
        // Read first Header bytes,
        // Determined the algorithm that was used for the encryption
        // Create a buffered cryptor with algorithms parsed using CipherMessage mehtods
        self.setDecryptorFromFile(with: completion)
        self.outputStream.open()
        performReadAndWrite(with: completion)
    }
    
    
    
// MARK: Helper Function part
    mutating func setCryptor(with ivData: Data) -> () {
        self.bufferedCryptor = BufferedSharedKeyCryptor(algorithm: self.fileCipherMessage.algorithm, mode: self.fileCipherMessage.blockMode)
        
        // set the right key
        let keyData: Data
        if self.key.count < self.fileCipherMessage.algorithm.keysize {
            log(info:"The key that is given is not long enough, the length of key should be \(self.fileCipherMessage.algorithm.keysize), we will expand current key with 0 to reach the length ")
            var targetKeyData = self.key
            let zeroData = Data(count: self.fileCipherMessage.algorithm.keysize - self.key.count)
            targetKeyData.append(zeroData)
            keyData = targetKeyData
        } else {
            log(info:"The key that is given is longer than the length it should be, which is \(self.fileCipherMessage.algorithm.keysize), we will truncate current key to reach the length ")
            keyData = self.key.subdata(in: 0 ..< self.fileCipherMessage.algorithm.keysize)
        }
        
        switch self.operation {
        case .encrypt:
            try? self.bufferedCryptor.startEncryption(keyData, iv: ivData)
        case .decrypt:
            try? self.bufferedCryptor.startDecryption(keyData, iv: ivData)
        }
        
    }
    
    func closeStreams() -> () {
        self.inputStream.close()
        self.outputStream.close()
    }
    
    static func setFileProtectionAttributes(atPath filePath: String) -> Bool {
        let pathURL = URL(fileURLWithPath: filePath)
        let excludedFormats: Set = ["aac", "asts", "aif", "aiff", "aifc", "caf", "mp3", "mp4", "m4a", "snd", "au", "sd2", "wav", "msg"]
        let fileBelongsToExcludedFormats = excludedFormats.contains(pathURL.pathExtension)
        let fileProtectionAttributes = fileBelongsToExcludedFormats ?
            [FileAttributeKey.protectionKey: FileProtectionType.completeUnlessOpen] : [FileAttributeKey.protectionKey: FileProtectionType.complete]
        do {
            try FileManager.default.setAttributes(fileProtectionAttributes, ofItemAtPath: filePath)
        } catch {
            log(error:"Cannot set protection attributes")
            return false
        }
        return true
    }
}


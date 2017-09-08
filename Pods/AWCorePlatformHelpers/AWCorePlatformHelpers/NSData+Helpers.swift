//
//  NSData+Helpers.swift
//  AWCorePlatformHelpers
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//
import Foundation

extension Data {
    public var hexadecimalString: String {
        var byteArray = [UInt8](repeating: 0x0, count: self.count)
        self.copyBytes(to: &byteArray, count: self.count)
        return byteArray
            .map { String(format: "%02x", $0) }
            .reduce( "", + )
    }
    
    public static func base64DecodeData(_ encodedText:String) -> Data? {
        if encodedText.characters.count < 4 {
            return nil
        }
        var base64DecodedData:Data? = nil
        if encodedText.characters.count > 0 {
            base64DecodedData = Data(base64Encoded: encodedText, options: Data.Base64DecodingOptions.ignoreUnknownCharacters)
        }
        return base64DecodedData

    }
}


extension NSData {
    @objc(aw_hexadecimalString)
    public var hexadecimalString: String {
        return Data(bytes: self.bytes, count: self.length).hexadecimalString
    }
    
    @objc(AW_base64DecodedData:)
    public static func base64DecodedData(_ encodedText:String) -> NSData? {
        let data = Data.base64DecodeData(encodedText) as NSData?
        return data
    }
}

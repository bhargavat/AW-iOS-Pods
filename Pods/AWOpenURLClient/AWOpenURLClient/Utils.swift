//
//  AWAUtils.swift
//  AWAnchorSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

// Helpful utility computed variables and functions

extension Dictionary
    where Key: ExpressibleByStringLiteral, Value: ExpressibleByStringLiteral {
    /// Convert a [String: String] dictionary to an http encoded parameter string
    internal var httpEncodedParameterString: String {
        // Based upon: http://stackoverflow.com/questions/27723912/swift-get-request-with-parameters
        let parameterArray = self.map {
            (key, value) -> String in

            let encodedKey = (key as! String).stringByHttpEncoding
            let encodedValue = (value as! String).stringByHttpEncoding

            return "\(encodedKey)=\(encodedValue)"
        }.sorted()

        return parameterArray.joined(separator: "&")
    }
}

extension URL {
    /// Extract the query item from the URL, if present
    internal func queryItem(key: String) -> String? {
        guard let urlComponents = URLComponents(url: self,
                                                  resolvingAgainstBaseURL: true),
            let queryItems = urlComponents.queryItems, queryItems.count > 0
            else {
                return nil
        }
        
        //check this part with WS1 team (since they were not removing encodings while reading back the response)
        return queryItems.filter {$0.name.lowercased() == key.lowercased()}
            .first?.value
    }
}

extension String {
    /// HTTP encode the string, if possible
    internal var stringByHttpEncoding: String {
        guard let result = self.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
            return self
        }
        return result
    }
    
    internal var isValidHexadecimalString: Bool {
        let chars = CharacterSet(charactersIn: "0123456789ABCDEF").inverted
        guard (self.uppercased().rangeOfCharacter(from: chars) == nil) else {
            return false
        }
        return true
    }
}

extension Data {
    public var hexString: String {
        var byteArray = [UInt8](repeating: 0x0, count: self.count)
        self.copyBytes(to: &byteArray, count: self.count)
        return byteArray
            .map { String(format: "%02x", $0) }
            .reduce( "", + )
    }

}


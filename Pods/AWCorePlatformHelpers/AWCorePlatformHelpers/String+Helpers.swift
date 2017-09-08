//
//  String+Helpers.swift
//  AWCorePlatformHelpers
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

extension NSString {

    public var isExtensionBundlePath: Bool {
        return self.pathExtension.caseInsensitiveCompare("appex") == .orderedSame
    }

}

public extension String {

    public var isExtensionBundlePath: Bool {
        return (self as NSString).isExtensionBundlePath
    }

}


extension String {

    func isEmail() -> Bool {
        let laxString = ".+@([A-Za-z0-9-]+\\.)+[A-Za-z]{2}[A-Za-z]*"
        let emailTest = NSPredicate(format: "SELF MATCHES %@", laxString)
        return emailTest.evaluate(with: self)
    }
    
    func boolValue() -> Bool {
        switch self.lowercased() {
            case "false": return false
            case "0": return false
            case "1": return true
            case "true": return true
            case "yes": return true
        default: return false
        }
    }
}

extension String {

    func urlDomainMatches( _ request: String) -> Bool {
        let schemeRegex = "((https?|ftps?)://)?"
        let wildcard = "*"
        let domainRegex = "([\\.\\-0-9a-zA-Z])*"
        
        var preprocessedURL = self
        if !(preprocessedURL.hasPrefix("http") || preprocessedURL.hasPrefix("ftp")) {
            preprocessedURL = schemeRegex + preprocessedURL
        }
        
        preprocessedURL = preprocessedURL.replacingOccurrences(of: wildcard, with: domainRegex)
        
        /// Add Regex start and end markers
        preprocessedURL = "^\(preprocessedURL)$"
        
        let regex = try? NSRegularExpression(pattern: preprocessedURL, options: NSRegularExpression.Options.caseInsensitive)
        
        if let matches = regex?.numberOfMatches(in: request, options: NSRegularExpression.MatchingOptions.anchored, range: NSMakeRange(0, request.characters.count)) {
            return matches > 0
        }
        
        return false
    }

}

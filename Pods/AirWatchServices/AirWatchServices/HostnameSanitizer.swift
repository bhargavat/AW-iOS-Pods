//
//  HostnameSanitizer.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation

internal class HostnameSanitizer {

    fileprivate static let supportedSchemes: [String] = ["https", "http"]

    internal static func getSanitizedHTTPUrls(_ hostname: String) -> [String] {

        let components = hostname.components(separatedBy: "://")
        guard let lastElement = components.last else {
            return []
        }

        let reconstructuedHostname = "https://\(lastElement)"
        var urlsList: [String] = []
        for scheme in HostnameSanitizer.supportedSchemes {
            if let hostnameComponentsTemp: URLComponents = URLComponents(string: reconstructuedHostname) {
                var hostnameComponents: URLComponents = hostnameComponentsTemp
                hostnameComponents.scheme = scheme
                if let finalURL = hostnameComponents.url {
                    urlsList.append(finalURL.absoluteString)
                }
            }
        }
        return urlsList
    }

}
